#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - #{ @coin.upcase } stale block candidates"
    xml.description "When there are multiple blocks at the tip height, one will become stale"
    xml.link root_url

    @stale_candidates.each do |stale_candidate|
      xml.item do
        xml.title "There are #{ Block.where(coin: stale_candidate.coin, height: stale_candidate.height).count } distinct blocks at height #{ stale_candidate.height }"
        xml.description "Blocks: #{ Block.where(coin: stale_candidate.coin, height: stale_candidate.height).collect {|block| block.block_hash + " (#{ block.pool.present? ? block.pool : "Unknown pool" })" }.join(', ')}"
        xml.pubDate stale_candidate.created_at.to_s(:rfc822)
        xml.link api_v1_stale_candidate_url(stale_candidate)
        xml.guid api_v1_stale_candidate_url(stale_candidate)
      end
    end
  end
end
