# frozen_string_literal: true

module BitcoinUtil
  class Version
    class << self
      def parse(version)
        return if version.nil?

        if version.is_a?(String) && version.split('.').count >= 3
          digits = version.split('.').collect(&:to_i)
          padding = [0] * (4 - digits.size)
          digits.push(*padding)
          digits[3] + digits[2] * 100 + digits[1] * 10_000 + digits[0] * 1_000_000
        else
          version
        end
      end

      def name_with_version(name, version, version_extra, is_bu)
        name = name.to_s
        if version.nil?
          if version_extra.present?
            # Allow admin to hardcode version
            name += " #{version_extra}"
          end
          return name
        end
        version_arr = version.to_s.rjust(8, '0').scan(/.{1,2}/).map(&:to_i)
        name + " #{(version_arr[3]).zero? && !is_bu ? version_arr[0..2].join('.') : version_arr.join('.')}" + version_extra
      end
    end
  end
end
