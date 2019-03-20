#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Nodes behind"
    xml.description "Test nodes that are behind, but not due to being offline or in initial block download."
    xml.link root_url

    @nodes_behind.each do |node_behind|
      xml.item do
        xml.title "#{ node_behind.node_a.name_with_version } is #{ node_behind.node_b.block.height - node_behind.node_a.block.height } blocks behind #{ node_behind.node_b.version }"
        xml.pubDate node_behind.created_at.to_s(:rfc822)
      end
    end
  end
end
