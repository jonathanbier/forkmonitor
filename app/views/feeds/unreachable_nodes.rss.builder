# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title 'Fork Monitor - Unreachable nodes'
    xml.description "Nodes that are not reachable, probably because they're offline"
    xml.link root_url

    @unreachable_nodes.each do |node|
      cache node do
        xml.item do
          title_prefix = "#{node.name_with_version} (#{node.coin}) "
          title_node = node.unreachable_since.nil? ? '' : "has been unreachable since #{node.unreachable_since.to_s(:rfc822)} "
          title_mirror_node = node.mirror_unreachable_since.nil? ? '' : "mirror has been unreachable since #{node.mirror_unreachable_since.to_s(:rfc822)}."
          title_node += 'and ' if !node.unreachable_since.nil? && !node.mirror_unreachable_since.nil?
          timestamp = node.unreachable_since.nil? ? node.mirror_unreachable_since : node.unreachable_since
          xml.title title_prefix + title_node + title_mirror_node
          xml.pubDate timestamp.to_s(:rfc822)
          xml.link root_url
          xml.guid api_v1_node_url(node)
        end
      end
    end
  end
end
