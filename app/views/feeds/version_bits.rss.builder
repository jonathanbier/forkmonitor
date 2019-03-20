#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Version bits"
    xml.description "Version bits signalled more than #{ ENV['VERSION_BITS_THRESHOLD'] } times during 100 blocks."
    xml.link root_url

    @version_bits.each do |version_bit|
      xml.item do
        xml.title "Bit #{ version_bit.bit } set between blocks #{ version_bit.activate.height - VersionBit::WINDOW + 1 } and #{ version_bit.activate.height }"
        xml.description ""
        xml.pubDate version_bit.created_at.to_s(:rfc822)
        xml.link api_v1_version_bit_url(version_bit)
        xml.guid api_v1_version_bit_url(version_bit)
      end
    end
  end
end
