#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Lightning potential uncooperative close transactions"
    xml.description "When a channel is closed uncooperatively, it looks like a spend from a regular 2-of-2 multisig, so this feed may contain false positives."
    xml.link feeds_ln_uncoops_url(@coin) + "?page=#{@page}", rel: "self"
    xml.link feeds_ln_uncoops_url(@coin) + "?page=1", rel: "first"
    xml.link feeds_ln_uncoops_url(@coin) + "?page=#{@page + 1}", rel: "next" if @page < @page_count
    xml.link feeds_ln_uncoops_url(@coin) + "?page=#{@page - 1}", rel: "previous" if @page > 1
    xml.link feeds_ln_uncoops_url(@coin) + "?page=#{@page_count}", rel: "last"
  
    xml.lastBuildDate MaybeUncoopTransaction.last_updated_cached.updated_at.iso8601
    xml.updated MaybeUncoopTransaction.last_updated_cached.updated_at.iso8601

    cache @ln_uncoops do
      @ln_uncoops.each do |uncoop|
        cache uncoop do
          xml.item do
            xml.title "Potential uncooperative close transaction at height #{ uncoop.block.height }"
            xml.description "otential uncooperative close transaction #{ uncoop.tx_id } at height #{ uncoop.block.height }"
            xml.pubDate Time.at(uncoop.block.timestamp).to_datetime.iso8601
            xml.link uncoop.channel_is_public ? "https://1ml.com/channel/#{ uncoop.channel_id_1ml }" : "https://blockstream.info/tx/#{ uncoop.tx_id }?expand"
            xml.guid api_v1_ln_uncoop_url(uncoop)
          end
        end
      end
    end
  end
end
