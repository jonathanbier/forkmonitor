# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title "Fork Monitor - Invalid #{@coin.upcase} blocks"
    xml.description 'Blocks considered valid by one node, but invalid by another'
    xml.link root_url

    @invalid_blocks.each do |invalid_block|
      cache invalid_block do
        xml.item do
          xml.title "Block #{invalid_block.block.height} marked invalid by #{invalid_block.node.name_with_version}"
          xml.description "Block #{invalid_block.block.height} (#{invalid_block.block.summary}) marked invalid by #{invalid_block.node.name_with_version}. This block was accepted as valid by #{Node.find(invalid_block.block.marked_valid_by.first).name_with_version}."
          xml.pubDate invalid_block.created_at.to_s(:rfc822)
          xml.link api_v1_invalid_block_url(invalid_block)
          xml.guid api_v1_invalid_block_url(invalid_block)
        end
      end
    end
  end
end
