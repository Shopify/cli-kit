# typed: true

require 'cli/kit'
require 'fileutils'

module CLI
  module Kit
    class Config
      XDG_CONFIG_HOME = 'XDG_CONFIG_HOME'

      #: (tool_name: String) -> void
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
      #: (String section, String name, ?default: String?) -> String?
      def get(section, name, default: nil)
        all_configs.dig("[#{section}]", name) || default
      end

      # Coalesce and enforce the value of a config to a boolean
      #: (String section, String name, ?default: bool?) -> bool?
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
      #: (String section, String name, (String | bool)? value) -> void
      def set(section, name, value)
        all_configs["[#{section}]"] ||= {}
        section = all_configs["[#{section}]"] #: as !nil
        case value
        when nil
          section.delete(name)
        else
          section[name] = value.to_s
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
      #: (String section, String name) -> void
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
      #: (String section) -> Hash[String, String]
      def get_section(section)
        (all_configs["[#{section}]"] || {}).dup
      end

      #: -> String
      def to_s
        ini.to_s
      end

      # The path on disk at which the configuration is stored:
      #   `$XDG_CONFIG_HOME/<toolname>/config`
      # if ENV['XDG_CONFIG_HOME'] is not set, we default to ~/.config, e.g.:
      #   ~/.config/tool/config
      #
      #: -> String
      def file
        config_home = ENV.fetch(XDG_CONFIG_HOME, '~/.config')
        File.expand_path(File.join(@tool_name, 'config'), config_home)
      end

      private

      #: -> Hash[String, Hash[String, String]]
      def all_configs
        ini.ini
      end

      #: -> CLI::Kit::Ini
      def ini
        @ini ||= CLI::Kit::Ini.new(file).tap(&:parse)
      end

      #: -> void
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
