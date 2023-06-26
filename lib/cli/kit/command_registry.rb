# typed: true

require 'cli/kit'

module CLI
  module Kit
    class CommandRegistry
      extend T::Sig

      CommandOrProc = T.type_alias do
        T.any(T.class_of(CLI::Kit::BaseCommand), T.proc.returns(T.class_of(CLI::Kit::BaseCommand)))
      end

      sig { returns(T::Hash[String, CommandOrProc]) }
      attr_reader :commands

      sig { returns(T::Hash[String, String]) }
      attr_reader :aliases

      module ContextualResolver
        extend T::Sig
        extend T::Helpers
        interface!

        sig { abstract.returns(T::Array[String]) }
        def command_names; end

        sig { abstract.returns(T::Hash[String, String]) }
        def aliases; end

        sig { abstract.params(_name: String).returns(T.class_of(CLI::Kit::BaseCommand)) }
        def command_class(_name); end
      end

      module NullContextualResolver
        extend T::Sig
        extend ContextualResolver

        class << self
          extend T::Sig

          sig { override.returns(T::Array[String]) }
          def command_names
            []
          end

          sig { override.returns(T::Hash[String, String]) }
          def aliases
            {}
          end

          sig { override.params(_name: String).returns(T.class_of(CLI::Kit::BaseCommand)) }
          def command_class(_name)
            raise(CLI::Kit::Abort, 'Cannot be called on the NullContextualResolver since command_names is empty')
          end
        end
      end

      sig { params(default: String, contextual_resolver: ContextualResolver).void }
      def initialize(default:, contextual_resolver: NullContextualResolver)
        @commands = {}
        @aliases  = {}
        @default = default
        @contextual_resolver = contextual_resolver
      end

      sig { returns(T::Hash[String, T.class_of(CLI::Kit::BaseCommand)]) }
      def resolved_commands
        @commands.each_with_object({}) do |(k, v), a|
          a[k] = resolve_class(v)
        end
      end

      sig { params(const: CommandOrProc, name: String).void }
      def add(const, name)
        commands[name] = const
      end

      sig { params(name: T.nilable(String)).returns([T.nilable(T.class_of(CLI::Kit::BaseCommand)), String]) }
      def lookup_command(name)
        name = @default if name.to_s.empty?
        resolve_command(T.must(name))
      end

      sig { params(from: String, to: String).void }
      def add_alias(from, to)
        aliases[from] = to unless aliases[from]
      end

      sig { returns(T::Array[String]) }
      def command_names
        @contextual_resolver.command_names + commands.keys
      end

      sig { params(name: String).returns(T::Boolean) }
      def exist?(name)
        !resolve_command(name).first.nil?
      end

      private

      sig { params(name: String).returns(String) }
      def resolve_alias(name)
        aliases[name] || @contextual_resolver.aliases.fetch(name, name)
      end

      sig { params(name: String).returns([T.nilable(T.class_of(CLI::Kit::BaseCommand)), String]) }
      def resolve_command(name)
        name = resolve_alias(name)
        resolve_global_command(name) ||
          resolve_contextual_command(name) ||
          [nil, name]
      end

      sig { params(name: String).returns(T.nilable([T.class_of(CLI::Kit::BaseCommand), String])) }
      def resolve_global_command(name)
        klass = resolve_class(commands.fetch(name, nil))
        return unless klass

        [klass, name]
      rescue NameError
        nil
      end

      sig { params(name: String).returns(T.nilable([T.class_of(CLI::Kit::BaseCommand), String])) }
      def resolve_contextual_command(name)
        found = @contextual_resolver.command_names.include?(name)
        return unless found

        [@contextual_resolver.command_class(name), name]
      end

      sig { params(class_or_proc: T.nilable(CommandOrProc)).returns(T.nilable(T.class_of(CLI::Kit::BaseCommand))) }
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
