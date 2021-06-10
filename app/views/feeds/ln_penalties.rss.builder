# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title 'Fork Monitor - Lightning penalty transactions'
    xml.description 'When a revoked commitment is used, the other party can claim all the funds (BOLT-3).'
    xml.link root_url

    xml.lastBuildDate PenaltyTransaction.last_updated_cached.updated_at.iso8601
    xml.updated PenaltyTransaction.last_updated_cached.updated_at.iso8601

    cache @ln_penalties do
      @ln_penalties.each do |penalty|
        cache penalty do
          xml.item do
            xml.title "Penalty transaction at height #{penalty.block.height}"
            xml.description "Penalty transaction #{penalty.tx_id} at height #{penalty.block.height}"
            xml.pubDate Time.at(penalty.block.timestamp).to_datetime.iso8601
            xml.link penalty.channel_is_public ? "https://1ml.com/channel/#{penalty.channel_id_1ml}" : "https://blockstream.info/tx/#{penalty.tx_id}?expand"
            xml.guid api_v1_ln_penalty_url(penalty)
          end
        end
      end
    end
  end
end
