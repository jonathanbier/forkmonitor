# Preview all emails at http://localhost:3000/rails/mailers/nodes_mailer
class NodesMailerPreview < ActionMailer::Preview
  def version_bits_email
    @version_bit = VersionBit.last
    tally = 1 # TODO: store in VersionBit
    @block = Block.find(@version_bit.activate_block_id)
    UserMailer.with(user: User.first, bit: @version_bit.bit, tally: 1, window: VersionBit::WINDOW, block: @block).version_bits_email
  end

  def orphan_candidate_email
    @orphan_candidate = OrphanCandidate.new(height: Block.last.height, coin: :btc)
    UserMailer.with(user: User.first, orphan_candidate: @orphan_candidate).orphan_candidate_email
  end
end
