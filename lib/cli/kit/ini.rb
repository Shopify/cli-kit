# typed: true
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
      extend(T::Sig)

      LeafValue = T.type_alias(T.any(String, Integer, Float, NilClass))
      Value = T.type_alias(T.any(T::Hash[String, LeafValue], LeafValue))
      IniType = T.type_alias(T::Hash[String, Value])

      sig { returns(IniType) }
      attr_reader(:ini)

      sig { params(ini: IniType).void }
      attr_writer(:ini)

      sig do
        params(
          path: T.nilable(String),
          config: T.nilable(String),
          default_section: T.nilable(String),
          convert_types: T::Boolean,
        ).void
      end
      def initialize(path = nil, config: nil, default_section: nil, convert_types: true)
        @config = if path && File.exist?(path)
          File.readlines(path)
        elsif config
          config.lines
        end
        @ini = {}
        @current_key = nil
        @default_section = default_section
        @convert_types = convert_types
      end

      sig { returns(IniType) }
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
            k, v = l.split('=', 2).map(&:strip)
            set_val(k, v)
          end
        end
        @ini
      end

      sig { returns(String) }
      def git_format
        to_ini(@ini, git_format: true).flatten.join("\n")
      end

      sig { returns(String) }
      def to_s
        to_ini(@ini).flatten.join("\n")
      end

      private

      sig { params(h: IniType, git_format: T::Boolean).returns(T::Array[T.any(String, T::Array[String])]) }
      def to_ini(h, git_format: false)
        optional_tab = git_format ? "\t" : ""
        str = []
        h.each do |k, v|
          if section_designator?(k) && v.is_a?(Hash)
            str << "" unless str.empty? || git_format
            str << k
            str << to_ini(v, git_format: git_format)
          else
            str << "#{optional_tab}#{k} = #{v}"
          end
        end
        str
      end

      sig { params(key: T.nilable(String), val: T.nilable(String)).void }
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

      sig { params(val: T.nilable(String)).returns(LeafValue) }
      def typed_val(val)
        return val.to_s unless @convert_types
        return val.to_i if val =~ /^-?[0-9]+$/
        return val.to_f if val =~ /^-?[0-9]+\.[0-9]*$/
        val.to_s
      end

      sig { params(k: String).returns(T::Boolean) }
      def section_designator?(k)
        k.start_with?('[') && k.end_with?(']')
      end
    end
  end
end
