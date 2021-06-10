# frozen_string_literal: true

module TxIdConcern # rubocop:todo Style/Documentation
  extend ActiveSupport::Concern
  class NilError < StandardError; end
  class_methods do
    def get_binary_chunks(data, size)
      raise NilError if data.nil?

      Array.new(((data.length + size - 1) / size)) { |i| data.byteslice(i * size, size) }
    end

    def hashes_to_binary(hashes)
      hashes.collect do |hash|
        [hash].pack('H*')
      end.join
    end

    def binary_to_hashes(binary)
      raise NilError if binary.nil?

      get_binary_chunks(binary, 32).collect do |chunck|
        chunck.unpack1('H*')
      end
    end
  end
end
