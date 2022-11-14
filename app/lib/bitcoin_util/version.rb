# frozen_string_literal: true

module BitcoinUtil
  class Version
    class << self
      def parse(version, client_type)
        return if version.nil?
        raise unless client_type.is_a? Symbol

        if version.is_a?(String) && version.split('.').count >= 2
          digits = version.split('.').collect(&:to_i)
          padding = [0] * (4 - digits.size)
          digits.push(*padding)
          if client_type == :core && digits[0] >= 22
            digits[2] + (digits[1] * 100) + (digits[0] * 10_000)
          else
            digits[3] + (digits[2] * 100) + (digits[1] * 10_000) + (digits[0] * 1_000_000)
          end
        else
          version
        end
      end

      def name_with_version(name, version, version_extra, client_type)
        raise unless client_type.is_a? Symbol

        name = name.to_s
        if version.nil?
          if version_extra.present?
            # Allow admin to hardcode version
            name += " #{version_extra}"
          end
          return name
        end
        if client_type == :core && version >= 220_000
          version_arr = version.to_s.rjust(6, '0').scan(/.{1,2}/).map(&:to_i)
          name + " #{(version_arr[2]).zero? ? version_arr[0..1].join('.') : version_arr.join('.')}" + version_extra
        else
          version_arr = if client_type == :sv
                          (version - 100_000_000).to_s.rjust(8, '0').scan(/.{1,2}/).map(&:to_i)
                        else
                          version.to_s.rjust(8, '0').scan(/.{1,2}/).map(&:to_i)
                        end
          name + " #{(version_arr[3]).zero? && client_type != :bu ? version_arr[0..2].join('.') : version_arr.join('.')}" + version_extra
        end
      end
    end
  end
end
