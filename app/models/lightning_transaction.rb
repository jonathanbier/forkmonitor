class LightningTransaction < ApplicationRecord
  belongs_to :block

  def as_json(options = nil)
    fields = [:id, :tx_id, :amount, :opening_tx_id]
    super({ only: fields }.merge(options || {})).merge({
      block: block
    })
  end

  def get_opening_tx_id!()
    justice_tx = Bitcoin::Protocol::Tx.new([self.raw_tx].pack('H*'))
    throw "Unexpected input count #{ justice_tx.in.count } for justice transaction" if justice_tx.in.count != 1
    close_tx_id = justice_tx.in.first.prev_out_hash.reverse.unpack("H*")[0]
    close_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(close_tx_id)
    close_tx = Bitcoin::Protocol::Tx.new([close_tx_raw].pack('H*'))
    throw "Unexpected input count #{ justice_tx.in.count } for closing transaction" if close_tx.in.count != 1
    opening_tx_id = close_tx.in.first.prev_out_hash.reverse.unpack("H*")[0]
    # Sanity check, raw transction is unused:
    opening_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(opening_tx_id)
    return opening_tx_id
  end

  def self.check!(options)
    throw "Only BTC mainnet supported" unless options[:coin].nil? || options[:coin] == :btc
    max = options[:max].present? ? options[:max] : 10
    node = Node.bitcoin_core_by_version.first
    puts "Scan blocks for relevant Lightning transactions using #{ node.name_with_version }..." unless Rails.env.test?

    blocks_to_check = [node.block]
    block = node.block
    while true
      # Don't perform lightning checks for more than 10 (default) blocks; it will take too long to catch up
      if blocks_to_check.count > max
        max_exceeded = true
        break
      end
      throw "Unable to perform lightning checks due to missing intermediate block" if block.parent.nil?
      block = block.parent
      break if block.checked_lightning
      blocks_to_check.unshift(block)
    end

    blocks_to_check.each do |block|
      raw_block = node.client.getblock(block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      puts "Block #{ block.height } (#{ block.block_hash }, #{ parsed_block.tx.count } txs)" unless Rails.env.test?
      self.check_penalties!(block, parsed_block)
      block.update checked_lightning: true
    end

    if max_exceeded
      raise "More than #{ max } blocks behind for lightning checks, please manually check blocks before #{ blocks_to_check.first.height } (#{ blocks_to_check.first.block_hash })"
    end
  end

  def self.check_penalties!(block, parsed_block)
    # Based on: https://github.com/alexbosworth/bolt03/blob/master/breaches/is_remedy_witness.js
    parsed_block.transactions.each do |tx|
      tx.in.each do |tx_in|
        # Must have a witness
        break if tx_in.script_witness.empty?
        # Witness must have the correct number of elements
        break unless tx_in.script_witness.stack.length == 3
        signature, flag, toLocalScript = tx_in.script_witness.stack
        # Signature must be DER encoded
        break unless Bitcoin::Script.is_der_signature?(signature)
        # Script path must be one of justice (non zero switches to OP_IF)
        break unless flag.unpack('H*')[0] == "01"

        script = Bitcoin::Script.new(toLocalScript)
        # Witness script must match expected pattern (BOLT #3)
        chunks = script.chunks
        break unless chunks.length == 9
        # OP_IF
        break unless chunks.shift() == Bitcoin::Script::OP_IF
        #  <revocationpubkey>
        break unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift())
        #  OP_ELSE
        break unless chunks.shift() == Bitcoin::Script::OP_ELSE
        #      `to_self_delay`
        break if chunks.shift().instance_of? Bitcoin::Script
        #      OP_CHECKSEQUENCEVERIFY
        break unless chunks.shift() == Bitcoin::Script::OP_NOP3
        #      OP_DROP
        break unless chunks.shift() == Bitcoin::Script::OP_DROP
        #      <local_delayedpubkey>
        break unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift())
        #  OP_ENDIF
        break unless chunks.shift() == Bitcoin::Script::OP_ENDIF
        #  OP_CHECKSIG
        break unless chunks.shift() == Bitcoin::Script::OP_CHECKSIG

        puts "Penalty: #{ tx.hash }" unless Rails.env.test?

        ln = block.lightning_transactions.build(
          tx_id: tx.hash,
          raw_tx: tx.payload.unpack('H*')[0],
          amount: tx.out.count == 1 ? tx.out[0].value : 0,
        )
        ln.opening_tx_id = ln.get_opening_tx_id!
        ln.save        
        # TODO: set amount based on output of previous transaction
      end
    end
  end

end
