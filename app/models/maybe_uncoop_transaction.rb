# frozen_string_literal: true

class MaybeUncoopTransaction < LightningTransaction
  def self.check!(node, block, parsed_block)
    # An uncooperative channel closing looks just like spending a regular 2-of-2
    # multisig, so this will match false positives.
    parsed_block.transactions.each do |tx|
      next unless tx.out.each do |tx_out|
        # Should be a witness script or public key hash, i.e.:
        # 00 PUSH_20 KEY_HASH; or
        # 00 PUSH_32 SCRIPT_HASH
        break unless [22, 34].include?(tx_out.pk_script_length)

        script = Bitcoin::Script.new(tx_out.pk_script)
        break unless script.chunks.length == 2
        break if script.chunks[0] != Bitcoin::Script::OP_0
        break unless [20, 32].include? script.chunks[1].length
      end

      prev_out_hash = nil
      first_input = nil
      next unless tx.in.each_with_index do |tx_in, input|
        # All inputs must refer to the same transaction id
        first_input = input unless first_input.present?
        break if prev_out_hash.present? && tx_in.prev_out_hash != prev_out_hash

        prev_out_hash = tx_in.prev_out_hash

        # All inputs should spending from a multisig output

        # Must have a witness
        break if tx_in.script_witness.empty?
        # Witness must have the correct number of elements
        break unless tx_in.script_witness.stack.length == 4

        dummy, sig_1, sig_2, fundingScript = tx_in.script_witness.stack
        # Signatures must be DER encoded
        break unless Bitcoin::Script.is_der_signature?(sig_1)
        break unless Bitcoin::Script.is_der_signature?(sig_2)

        script = Bitcoin::Script.new(fundingScript)
        # Witness script must match expected pattern (BOLT #3)
        chunks = script.chunks
        break unless chunks.length == 5
        # OP_2
        break unless chunks.shift == Bitcoin::Script::OP_2
        #  <pubkey1>
        break unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift)
        #  <pubkey2>
        break unless Bitcoin::Script.check_pubkey_encoding?(chunks.shift)
        # OP_2
        break unless chunks.shift == Bitcoin::Script::OP_2
        #  OP_CHECKMULTISIG
        break unless chunks.shift == Bitcoin::Script::OP_CHECKMULTISIG

        break unless MaybeUncoopTransaction.where(tx_id: tx.hash, input: input).count.zero?
      end

      puts "Force-close candidate: #{tx.hash}" unless Rails.env.test?

      ln = block.maybe_uncoop_transactions.build(
        tx_id: tx.hash,
        input: first_input,
        raw_tx: tx.payload.unpack1('H*'),
        amount: tx.out.count == 1 ? tx.out[0].value / 100_000_000.0 : 0
      )
      tx_id, block_hash = ln.get_opening_tx_id_and_block_hash!(tx)
      coin = node.coin.to_sym
      ln.opening_tx_id = tx_id
      ln.opening_block = Block.find_by coin: coin, block_hash: block_hash
      ln.save
    end
  end

  private

  def expire_cache
    super
    Rails.cache.delete('api/v1/ln_uncoops.json')
  end
end
