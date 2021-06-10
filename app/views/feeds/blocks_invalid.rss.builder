# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title "Fork Monitor - Invalid #{@coin.upcase} blocks"
    xml.description 'Blocks considered valid by any node'
    xml.link root_url

    @blocks_invalid.each do |block|
      cache block do
        xml.item do
          xml.title "#{@coin.upcase} block #{block.height} marked invalid by #{Node.find(block.marked_invalid_by.first).name_with_version}"
          xml.description "#{@coin.upcase} block #{block.height} (#{block.summary}) marked invalid by  by #{Node.find(block.marked_invalid_by.first).name_with_version}."
          xml.pubDate block.created_at.to_s(:rfc822)
          xml.link api_v1_block_url(block)
          xml.guid api_v1_block_url(block)
        end
      end
    end
  end
end
