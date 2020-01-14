class SweepTransaction < LightningTransaction
  def get_opening_tx_id!
    sweep_tx = Bitcoin::Protocol::Tx.new([self.raw_tx].pack('H*'))
    close_tx_id = sweep_tx.in[self.input].prev_out_hash.reverse.unpack("H*")[0]
    close_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(close_tx_id)
    close_tx = Bitcoin::Protocol::Tx.new([close_tx_raw].pack('H*'))
    super(close_tx)
  end

  def self.check!(node, block, parsed_block)
    # Based on: https://github.com/alexbosworth/bolt03/blob/master/breaches/is_remedy_witness.js
    parsed_block.transactions.each do |tx|
      tx.in.each_with_index do |tx_in, input|
        # Must have a witness
        break if tx_in.script_witness.empty?
        # Witness must have the correct number of elements
        break unless tx_in.script_witness.stack.length == 3
        signature, flag, toLocalScript = tx_in.script_witness.stack
        # Signature must be DER encoded
        break unless Bitcoin::Script.is_der_signature?(signature)
        # Script path must be one of sweep (zero or empty switches to OP_IF)
        break unless flag.empty? || flag.unpack('H*')[0] == "00"
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

        break unless SweepTransaction.where(tx_id: tx.hash, input: input).count == 0

        puts "Sweep: #{ tx.hash }" unless Rails.env.test?

        ln = block.sweep_transactions.build(
          tx_id: tx.hash,
          input: input,
          raw_tx: tx.payload.unpack('H*')[0],
          amount: get_input_amount(node, tx, input)
        )
        ln.opening_tx_id = ln.get_opening_tx_id!
        ln.save

        ln.find_parent!
      end
    end
  end

  private

  def expire_cache
    super
    Rails.cache.delete("api/v1/ln_sweeps.json")
  end
end
