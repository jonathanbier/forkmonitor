#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Nodes behind"
    xml.description "Test nodes that are behind, but not due to being offline or in initial block download."
    xml.link root_url

    @lagging_nodes.each do |lagging_node|
      cache lagging_node do
        xml.item do
          xml.title "#{ lagging_node.node_a.name_with_version } is #{ lagging_node.node_b.block.height - lagging_node.node_a.block.height } blocks behind #{ lagging_node.node_b.name_with_version }"
          xml.pubDate lagging_node.created_at.to_s(:rfc822)
          xml.link api_v1_lagging_node_url(lagging_node)
          xml.guid api_v1_lagging_node_url(lagging_node)
        end
      end
    end
  end
end
