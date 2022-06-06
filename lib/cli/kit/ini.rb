# typed: true

require 'cli/kit'

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
      extend T::Sig

      sig { returns(T::Hash[String, T::Hash[String, String]]) }
      attr_accessor :ini

      sig do
        params(path: T.nilable(String), config: T.nilable(String), default_section: String).void
      end
      def initialize(path = nil, config: nil, default_section: '[global]')
        @config = if path && File.exist?(path)
          File.readlines(path)
        elsif config
          config.lines
        end
        @ini = {}
        @current_key = default_section
      end

      sig { returns(T::Hash[String, T::Hash[String, String]]) }
      def parse
        return @ini if @config.nil?

        @config.each do |l|
          l.strip!

          if section_designator?(l)
            @current_key = l
          else
            k, v = l.split('=', 2).map(&:strip)
            set_val(k, v) if k && v
          end
        end

        @ini
      end

      sig { returns(String) }
      def git_format
        to_ini(git_format: true)
      end

      sig { returns(String) }
      def to_s
        to_ini
      end

      private

      sig { params(git_format: T::Boolean).returns(String) }
      def to_ini(git_format: false)
        optional_tab = git_format ? "\t" : ''
        str = []
        @ini.each do |section_designator, section|
          str << '' unless str.empty? || git_format
          str << section_designator
          section.each do |k, v|
            str << "#{optional_tab}#{k} = #{v}"
          end
        end
        str.join("\n")
      end

      sig { params(key: String, val: String).void }
      def set_val(key, val)
        current_key = @current_key
        @ini[current_key] ||= {}
        @ini[current_key][key] = val
      end

      sig { params(k: String).returns(T::Boolean) }
      def section_designator?(k)
        k.start_with?('[') && k.end_with?(']')
      end
    end
  end
end
