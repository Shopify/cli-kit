module CLI
  module Kit
    # INI is a language similar to JSON or YAML, but simplied
    # The spec is here: https://en.wikipedia.org/wiki/INI_file
    # This parser includes supports for 2 very basic uses
    # - Sections
    # - Key Value Pairs (within and outside of the sections)
    #
    # [global]
    # key = val
    #
    # Nothing else is supported right now
    # See the ini_test.rb file for more examples
    #
    class Ini
      attr_accessor :ini

      def initialize(path = nil, default_section: nil, convert_types: true)
        @config = File.readlines(path) if path && File.exist?(path)
        @ini = {}
        @current_key = nil
        @default_section = default_section
        @convert_types = convert_types
      end

      def parse
        return @ini if @config.nil?

        @config.each do |l|
          l.strip!

          # If section, then set current key, this will nest the setting
          if section_designator?(l)
            @current_key = l

          # A new line will reset the current key
          elsif l.strip.empty?
            @current_key = nil

          # Otherwise set the values
          else
            k, v = l.split('=').map(&:strip)
            set_val(k, v)
          end
        end
        @ini
      end

      def to_s
        to_ini(@ini).flatten.join("\n")
      end

      private

      def to_ini(h)
        str = []
        h.each do |k, v|
          if section_designator?(k)
            str << "" unless str.empty?
            str << k
            str << to_ini(v)
          else
            str << "#{k} = #{v}"
          end
        end
        str
      end

      def set_val(key, val)
        return if key.nil? && val.nil?

        current_key = @current_key || @default_section
        if current_key
          @ini[current_key] ||= {}
          @ini[current_key][key] = typed_val(val)
        else
          @ini[key] = typed_val(val)
        end
      end

      def typed_val(val)
        return val.to_s unless @convert_types
        return val.to_i if val =~ /^-?[0-9]+$/
        return val.to_f if val =~ /^-?[0-9]+\.[0-9]*$/
        val.to_s
      end

      def section_designator?(k)
        k.start_with?('[') && k.end_with?(']')
      end
    end
  end
end
