# typed: true

require 'cli/kit'

module CLI
  module Kit
    class CommandRegistry
      #: type command_or_proc = singleton(CLI::Kit::BaseCommand) | ^() -> singleton(CLI::Kit::BaseCommand)

      #: Hash[String, command_or_proc]
      attr_reader :commands

      #: Hash[String, String]
      attr_reader :aliases

      # @interface
      module ContextualResolver
        # @abstract
        #: -> Array[String]
        def command_names
          raise(NotImplementedError)
        end

        # @abstract
        #: -> Hash[String, String]
        def aliases
          raise(NotImplementedError)
        end

        # @abstract
        #: (String) -> singleton(CLI::Kit::BaseCommand)
        def command_class(_name)
          raise(NotImplementedError)
        end
      end

      module NullContextualResolver
        extend ContextualResolver

        class << self
          # @override
          #: -> Array[String]
          def command_names
            []
          end

          # @override
          #: -> Hash[String, String]
          def aliases
            {}
          end

          # @override
          #: (String _name) -> singleton(CLI::Kit::BaseCommand)
          def command_class(_name)
            raise(CLI::Kit::Abort, 'Cannot be called on the NullContextualResolver since command_names is empty')
          end
        end
      end

      #: (default: String, ?contextual_resolver: ContextualResolver) -> void
      def initialize(default:, contextual_resolver: NullContextualResolver)
        @commands = {}
        @aliases  = {}
        @default = default
        @contextual_resolver = contextual_resolver
      end

      #: -> Hash[String, singleton(CLI::Kit::BaseCommand)]
      def resolved_commands
        @commands.each_with_object({}) do |(k, v), a|
          a[k] = resolve_class(v)
        end
      end

      #: (command_or_proc const, String name) -> void
      def add(const, name)
        commands[name] = const
      end

      #: (String? name) -> [singleton(CLI::Kit::BaseCommand)?, String]
      def lookup_command(name)
        name = @default if name.to_s.empty?
        resolve_command(
          name, #: as !nil
        )
      end

      #: (String from, String to) -> void
      def add_alias(from, to)
        aliases[from] = to unless aliases[from]
      end

      #: -> Array[String]
      def command_names
        @contextual_resolver.command_names + commands.keys
      end

      #: (String name) -> bool
      def exist?(name)
        !resolve_command(name).first.nil?
      end

      private

      #: (String name) -> String
      def resolve_alias(name)
        aliases[name] || @contextual_resolver.aliases.fetch(name, name)
      end

      #: (String name) -> [singleton(CLI::Kit::BaseCommand)?, String]
      def resolve_command(name)
        name = resolve_alias(name)
        resolve_global_command(name) ||
          resolve_contextual_command(name) ||
          [nil, name]
      end

      #: (String name) -> [singleton(CLI::Kit::BaseCommand), String]?
      def resolve_global_command(name)
        klass = resolve_class(commands.fetch(name, nil))
        return unless klass

        [klass, name]
      rescue NameError
        nil
      end

      #: (String name) -> [singleton(CLI::Kit::BaseCommand), String]?
      def resolve_contextual_command(name)
        found = @contextual_resolver.command_names.include?(name)
        return unless found

        [@contextual_resolver.command_class(name), name]
      end

      #: (command_or_proc? class_or_proc) -> singleton(CLI::Kit::BaseCommand)?
      def resolve_class(class_or_proc)
        case class_or_proc
        when nil
          nil
        when Proc
          class_or_proc.call
        else
          class_or_proc
        end
      end
    end
  end
end
