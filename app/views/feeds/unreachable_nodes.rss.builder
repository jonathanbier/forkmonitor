#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Unreachable nodes"
    xml.description "Nodes that are not reachable, probably because they're offline"
    xml.link root_url

    @unreachable_nodes.each do |node|
      cache node do
        xml.item do
          xml.title "#{ node.name_with_version } (#{ node.coin }) has been unreachable since #{ node.unreachable_since.to_s(:rfc822) }"
          xml.pubDate node.unreachable_since.to_s(:rfc822)
          xml.link root_url
          xml.guid api_v1_node_url(node)
        end
      end
    end
  end
end
