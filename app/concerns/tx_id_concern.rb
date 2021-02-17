module TxIdConcern
  extend ActiveSupport::Concern
  class NilError < StandardError; end
  class_methods do
    def get_binary_chunks(data, size)
      raise NilError if data.nil?
      Array.new(((data.length + size - 1) / size)) { |i| data.byteslice(i * size, size) }
    end

    def hashes_to_binary(hashes)
      hashes.collect {|hash|
        [hash].pack("H*")
      }.join()
    end

    def binary_to_hashes(binary)
      raise NilError if binary.nil?
      self.get_binary_chunks(binary,32).collect {|chunck|
        chunck.unpack("H*")[0]
      }
    end
  end
end
