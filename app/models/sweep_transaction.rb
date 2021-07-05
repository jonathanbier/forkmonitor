# frozen_string_literal: true

class SweepTransaction < LightningTransaction
  def get_opening_tx_id_and_block_hash!
    sweep_tx = Bitcoin::Protocol::Tx.new([raw_tx].pack('H*'))
    close_tx_id = sweep_tx.in[input].prev_out_hash.reverse.unpack1('H*')
    close_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(close_tx_id)
    close_tx = Bitcoin::Protocol::Tx.new([close_tx_raw].pack('H*'))
    super(close_tx)
  end

  private

  def expire_cache
    super
    Rails.cache.delete('api/v1/ln_sweeps.json')
  end

  class << self
    def check!(node, block, parsed_block)
      # Based on: https://github.com/alexbosworth/bolt03/blob/master/breaches/is_remedy_witness.js
      parsed_block.transactions.each do |tx|
        tx.in.each_with_index do |tx_in, input|
          # Must have a witness
          next if tx_in.script_witness.empty?
          # Witness must have the correct number of elements
          next unless tx_in.script_witness.stack.length == 3

          signature, flag, toLocalScript = tx_in.script_witness.stack
          # Signature must be DER encoded
          next unless Bitcoin::Script.is_der_signature?(signature)
          # Script path must be one of sweep (zero or empty switches to OP_IF)
          next unless flag.empty? || flag.unpack1('H*') == '00'

          script = Bitcoin::Script.new(toLocalScript)
          # Witness script must match expected pattern (BOLT #3)
          chunks = script.chunks
          next unless chunks.length == 9
          # OP_IF
          next unless chunks.shift == Bitcoin::Script::OP_IF
          #  <revocationpubkey>
          next unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift)
          #  OP_ELSE
          next unless chunks.shift == Bitcoin::Script::OP_ELSE
          #      `to_self_delay`
          next if chunks.shift.instance_of? Bitcoin::Script
          #      OP_CHECKSEQUENCEVERIFY
          next unless chunks.shift == Bitcoin::Script::OP_NOP3
          #      OP_DROP
          next unless chunks.shift == Bitcoin::Script::OP_DROP
          #      <local_delayedpubkey>
          next unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift)
          #  OP_ENDIF
          next unless chunks.shift == Bitcoin::Script::OP_ENDIF
          #  OP_CHECKSIG
          next unless chunks.shift == Bitcoin::Script::OP_CHECKSIG

          next unless SweepTransaction.where(tx_id: tx.hash, input: input).count.zero?

          puts "Sweep: #{tx.hash}" unless Rails.env.test?

          sweep_tx = block.sweep_transactions.build(
            tx_id: tx.hash,
            input: input,
            raw_tx: tx.payload.unpack1('H*'),
            amount: get_input_amount(node, tx, input)
          )
          coin = node.coin.to_sym
          tx_id, block_hash = sweep_tx.get_opening_tx_id_and_block_hash!
          sweep_tx.opening_tx_id = tx_id
          sweep_tx.opening_block = Block.find_by coin: coin, block_hash: block_hash
          sweep_tx.save

          sweep_tx.find_parent!
        end
      end
    end
  end
end
