# typed: true

require 'cli/kit'
require 'fileutils'

module CLI
  module Kit
    class Config
      extend T::Sig

      XDG_CONFIG_HOME = 'XDG_CONFIG_HOME'

      sig { params(tool_name: String).void }
      def initialize(tool_name:)
        @tool_name = tool_name
      end

      # Returns the config corresponding to `name` from the config file
      # `false` is returned if it doesn't exist
      #
      # #### Parameters
      # `section` : the section of the config value you are looking for
      # `name` : the name of the config value you are looking for
      #
      # #### Returns
      # `value` : the value of the config variable (nil if none)
      #
      # #### Example Usage
      # `config.get('name.of.config')`
      #
      sig { params(section: String, name: String, default: T.nilable(String)).returns(T.nilable(String)) }
      def get(section, name, default: nil)
        all_configs.dig("[#{section}]", name) || default
      end

      # Coalesce and enforce the value of a config to a boolean
      sig { params(section: String, name: String, default: T.nilable(T::Boolean)).returns(T.nilable(T::Boolean)) }
      def get_bool(section, name, default: false)
        case get(section, name)
        when 'true'
          true
        when 'false'
          false
        when nil
          default
        else
          raise CLI::Kit::Abort, "Invalid config: #{section}.#{name} is expected to be true or false"
        end
      end

      # Sets the config value in the config file
      #
      # #### Parameters
      # `section` : the section of the config you are setting
      # `name` : the name of the config you are setting
      # `value` : the value of the config you are setting
      #
      # #### Example Usage
      # `config.set('section', 'name.of.config', 'value')`
      #
      sig { params(section: String, name: String, value: T.nilable(T.any(String, T::Boolean))).void }
      def set(section, name, value)
        all_configs["[#{section}]"] ||= {}
        case value
        when nil
          T.must(all_configs["[#{section}]"]).delete(name)
        else
          T.must(all_configs["[#{section}]"])[name] = value.to_s
        end
        write_config
      end

      # Unsets a config value in the config file
      #
      # #### Parameters
      # `section` : the section of the config you are deleting
      # `name` : the name of the config you are deleting
      #
      # #### Example Usage
      # `config.unset('section', 'name.of.config')`
      #
      sig { params(section: String, name: String).void }
      def unset(section, name)
        set(section, name, nil)
      end

      # Gets the hash for the entire section
      #
      # #### Parameters
      # `section` : the section of the config you are getting
      #
      # #### Example Usage
      # `config.get_section('section')`
      #
      sig { params(section: String).returns(T::Hash[String, String]) }
      def get_section(section)
        (all_configs["[#{section}]"] || {}).dup
      end

      sig { returns(String) }
      def to_s
        ini.to_s
      end

      # The path on disk at which the configuration is stored:
      #   `$XDG_CONFIG_HOME/<toolname>/config`
      # if ENV['XDG_CONFIG_HOME'] is not set, we default to ~/.config, e.g.:
      #   ~/.config/tool/config
      #
      sig { returns(String) }
      def file
        config_home = ENV.fetch(XDG_CONFIG_HOME, '~/.config')
        File.expand_path(File.join(@tool_name, 'config'), config_home)
      end

      private

      sig { returns(T::Hash[String, T::Hash[String, String]]) }
      def all_configs
        ini.ini
      end

      sig { returns(CLI::Kit::Ini) }
      def ini
        @ini ||= CLI::Kit::Ini.new(file).tap(&:parse)
      end

      sig { void }
      def write_config
        all_configs.each do |section, sub_config|
          all_configs.delete(section) if sub_config.empty?
        end
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, to_s)
      end
    end
  end
end
