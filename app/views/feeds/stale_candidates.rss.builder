# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title 'Fork Monitor - Stale block candidates'
    xml.description 'When there are multiple blocks at the tip height, one will become stale'
    xml.link feeds_stale_candidate_url + "?page=#{@page}", rel: 'self'
    xml.link "#{feeds_stale_candidate_url}?page=1", rel: 'first'
    xml.link feeds_stale_candidate_url + "?page=#{@page + 1}", rel: 'next' if @page < @page_count
    xml.link feeds_stale_candidate_url + "?page=#{@page - 1}", rel: 'previous' if @page > 1
    xml.link feeds_stale_candidate_url + "?page=#{@page_count}", rel: 'last'

    if StaleCandidate.last_updated_cached.present?
      xml.lastBuildDate(StaleCandidate.last_updated_cached.try { |i| i.updated_at.iso8601 })
      xml.updated(StaleCandidate.last_updated_cached.try { |i| i.updated_at.iso8601 })
    end

    @stale_candidates.each do |stale_candidate|
      cache stale_candidate do
        xml.item do
          xml.title "There are #{stale_candidate.n_children} distinct blocks at height #{stale_candidate.height}"
          xml.description "Blocks: #{Block.where(height: stale_candidate.height).collect do |block|
                                       block.summary(time: true, first_seen_by: true)
                                     end.join(', ')}"
          xml.pubDate stale_candidate.created_at.to_s(:rfc822)
          xml.link stale_candidate_url('btc', stale_candidate.height)
          xml.guid stale_candidate_url('btc', stale_candidate.height)
        end
      end
    end
  end
end
