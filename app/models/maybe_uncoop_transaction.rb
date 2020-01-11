class MaybeUncoopTransaction < LightningTransaction
  def get_opening_tx_id!()
    close_tx = Bitcoin::Protocol::Tx.new([self.raw_tx].pack('H*'))
    throw "Unexpected input count #{ close_tx.in.count } for closing transaction" if close_tx.in.count != 1
    opening_tx_id = close_tx.in.first.prev_out_hash.reverse.unpack("H*")[0]
    # Sanity check, raw transction is unused:
    opening_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(opening_tx_id)
    return opening_tx_id
  end

  def self.check!(block, parsed_block)
    # An uncooperative channel closing looks just like spending a regular 2-of-2
    # multisig, so this will match false positives.
    parsed_block.transactions.each do |tx|
      # Must have one input
      break if tx.in.count != 1
      tx.in.each_with_index do |tx_in, input|
        # Must have a witness
        break if tx_in.script_witness.empty?
        # Witness must have the correct number of elements
        break unless tx_in.script_witness.stack.length == 4
        dummy, sig1, sig2, fundingScript = tx_in.script_witness.stack
        # Signatures must be DER encoded
        break unless Bitcoin::Script.is_der_signature?(sig1)
        break unless Bitcoin::Script.is_der_signature?(sig2)

        script = Bitcoin::Script.new(fundingScript)
        # Witness script must match expected pattern (BOLT #3)
        chunks = script.chunks
        break unless chunks.length == 5
        # OP_2
        break unless chunks.shift() == Bitcoin::Script::OP_2
        #  <pubkey1>
        break unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift())
        #  <pubkey2>
        break unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift())
        # OP_2
        break unless chunks.shift() == Bitcoin::Script::OP_2
        #  OP_CHECKMULTISIG
        break unless chunks.shift() == Bitcoin::Script::OP_CHECKMULTISIG

        puts "Force-close candidate: #{ tx.hash }" unless Rails.env.test?

        ln = block.maybe_uncoop_transactions.build(
          tx_id: tx.hash,
          input: input,
          raw_tx: tx.payload.unpack('H*')[0],
          amount: tx.out.count == 1 ? tx.out[0].value / 100000000.0 : 0,
        )
        ln.opening_tx_id = ln.get_opening_tx_id!
        ln.save
        # TODO: set amount based on output of previous transaction
      end
    end
  end

  private

  def expire_cache
    super
    Rails.cache.delete("api/v1/ln_uncoops.json")
  end
end
