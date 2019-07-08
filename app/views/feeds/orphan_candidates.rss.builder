#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - #{ @coin.upcase } orphan candidates"
    xml.description "Multiple blocks at the tip height are considered orphan candidates"
    xml.link root_url

    @orphan_candidates.each do |orphan_candidate|
      xml.item do
        xml.title "There are #{ Block.where(coin: orphan_candidate.coin, height: orphan_candidate.height).count } distinct blocks at height #{ orphan_candidate.height }"
        xml.description "Blocks: #{ Block.where(coin: orphan_candidate.coin, height: orphan_candidate.height).collect {|block| block.block_hash + " (#{ block.pool.present? ? block.pool : "Unknown pool" })" }.join(', ')}"
        xml.pubDate orphan_candidate.created_at.to_s(:rfc822)
        xml.link api_v1_orphan_candidate_url(orphan_candidate)
        xml.guid api_v1_orphan_candidate_url(orphan_candidate)
      end
    end
  end
end
