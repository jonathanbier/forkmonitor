#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Unknown pools"
    xml.description "Blocks with unidentified mining pool"
    xml.link root_url

    @unknown_pools.each do |block|
      cache block do
        xml.item do
          xml.title "Unknown pool at height #{ block.height }."
          xml.description "Block #{ block.summary } with coinbase message: #{ [block.coinbase_message].pack('H*') }"
          xml.pubDate block.created_at.to_s(:rfc822)
          xml.link api_v1_block_url(block)
          xml.guid api_v1_block_url(block)
        end
      end
    end
  end
end
