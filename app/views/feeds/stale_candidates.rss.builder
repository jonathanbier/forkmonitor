#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - #{ @coin.upcase } stale block candidates"
    xml.description "When there are multiple blocks at the tip height, one will become stale"
    xml.link feeds_stale_candidate_url(@coin) + "?page=#{@page}", rel: "self"
    xml.link feeds_stale_candidate_url(@coin) + "?page=1", rel: "first"
    xml.link feeds_stale_candidate_url(@coin) + "?page=#{@page + 1}", rel: "next" if @page < @page_count
    xml.link feeds_stale_candidate_url(@coin) + "?page=#{@page - 1}", rel: "previous" if @page > 1
    xml.link feeds_stale_candidate_url(@coin) + "?page=#{@page_count}", rel: "last"

    xml.lastBuildDate StaleCandidate.last_updated_cached(@coin).updated_at.iso8601
    xml.updated StaleCandidate.last_updated_cached(@coin).updated_at.iso8601

    @stale_candidates.each do |stale_candidate|
      cache stale_candidate do
        xml.item do
          xml.title "There are #{ Block.where(coin: stale_candidate.coin, height: stale_candidate.height).count } distinct blocks at height #{ stale_candidate.height }"
          xml.description "Blocks: #{ Block.where(coin: stale_candidate.coin, height: stale_candidate.height).collect {|block| block.summary(time = true) }.join(', ')}"
          xml.pubDate stale_candidate.created_at.to_s(:rfc822)
          xml.link api_v1_stale_candidate_url(stale_candidate)
          xml.guid api_v1_stale_candidate_url(stale_candidate)
        end
      end
    end
  end
end
