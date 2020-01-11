#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Lightning sweep transactions"
    xml.description "When a channel is closed uncooperatively, the closing party can sweep the funds after a delay (BOLT-3)."
    xml.link root_url

    xml.lastBuildDate LightningTransaction.last_updated_cached.updated_at.iso8601
    xml.updated LightningTransaction.last_updated_cached.updated_at.iso8601

    cache @ln_sweeps do
      @ln_sweeps.each do |sweep|
        cache sweep do
          xml.item do
            xml.title "Sweep transaction at height #{ sweep.block.height }"
            xml.description "Sweep transaction #{ sweep.tx_id } at height #{ sweep.block.height }"
            xml.pubDate Time.at(sweep.block.timestamp).to_datetime.iso8601
            xml.link sweep.channel_is_public ? "https://1ml.com/channel/#{ sweep.channel_id_1ml }" : "https://blockstream.info/tx/#{ sweep.tx_id }?expand"
            xml.guid api_v1_ln_sweep_url(sweep)
          end
        end
      end
    end
  end
end
