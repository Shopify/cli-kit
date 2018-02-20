require 'cli/kit'

module CLI
  module Kit
    module CommandRegistry
      attr_accessor :commands, :aliases, :command_path
      class << self
        attr_accessor :registry_target
      end

      def resolve_contextual_command
        nil
      end

      def contextual_aliases
        {}
      end

      def contextual_command_class(_name)
        raise NotImplementedError
      end

      def self.extended(base)
        raise "multiple registries unsupported" if self.registry_target
        self.registry_target = base
        base.commands = {}
        base.aliases = {}
      end

      def register(const, name = nil, path = nil)
        if name.nil?
          name = dash_case(const)
        end

        if path.nil?
          path = File.join(command_path, snake_case(const))
        end

        autoload(const, path)
        commands[name] = const
      end

      def lookup_command(name)
        return default_command if name.to_s == ""
        resolve_command(name)
      end

      def register_alias(from, to)
        aliases[from] = to unless aliases[from]
      end

      def resolve_command(name)
        resolve_global_command(name) || \
          resolve_contextual_command(name) || \
          [nil, resolve_alias(name)]
      end

      def resolve_alias(name)
        aliases[name] || contextual_aliases.fetch(name, name)
      end

      def resolve_global_command(name)
        name = resolve_alias(name)
        command_class = const_get(commands.fetch(name, ""))
        return nil unless command_class.defined?
        [command_class, name]
      rescue NameError
        nil
      end

      def resolve_contextual_command(name)
        name = resolve_alias(name)
        found = contextual_command_names.include?(name)
        return nil unless found
        [contextual_command_class(name), name]
      end

      def contextual_command_names
        []
      end

      def command_names
        contextual_command_names + commands.keys
      end

      def exist?(name)
        !resolve_command(name).first.nil?
      end

      private

      def snake_case(camel_case, seperator = "_")
        camel_case.to_s # MyCoolThing::MyAPIModule
          .gsub(/::/, '/') # MyCoolThing/MyAPIModule
          .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1#{seperator}\\2") # MyCoolThing::MyAPI_Module
          .gsub(/([a-z\d])([A-Z])/, "\\1#{seperator}\\2") # My_Cool_Thing::My_API_Module
          .downcase # my_cool_thing/my_api_module
      end

      def dash_case(camel_case)
        snake_case(camel_case, "-")
      end
    end
  end
end
