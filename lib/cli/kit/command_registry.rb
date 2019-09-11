# typed: true
require 'cli/kit'

module CLI
  module Kit
    class CommandRegistry
      extend(T::Sig)

      sig { returns(T::Hash[String, T.untyped]) }
      attr_reader(:commands)

      sig { returns(T::Hash[String, String]) }
      attr_reader(:aliases)

      module ContextualResolverInterface
        extend(T::Sig)
        extend(T::Helpers)
        interface!

        sig { abstract.returns(T::Array[String]) }
        def command_names; end

        sig { abstract.returns(T::Hash[String, String]) }
        def aliases; end

        sig { abstract.params(name: String).returns(T.nilable(Class)) }
        def command_class(name); end
      end

      module NullContextualResolver
        extend(T::Sig)
        extend(ContextualResolverInterface)

        sig { implementation.returns(T::Array[String]) }
        def self.command_names
          []
        end

        sig { implementation.returns(T::Hash[String, String]) }
        def self.aliases
          {}
        end

        sig { implementation.params(_name: String).returns(T.nilable(Class)) }
        def self.command_class(_name)
          nil
        end
      end

      sig do
        params(
          default: T.nilable(String),
          contextual_resolver: T.nilable(ContextualResolverInterface),
        ).void
      end
      def initialize(default:, contextual_resolver: nil)
        @commands = {}
        @aliases  = {}
        @default = default
        @contextual_resolver = contextual_resolver || NullContextualResolver
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def resolved_commands
        @commands.each_with_object({}) do |(k, v), a|
          a[k] = resolve_class(v)
        end
      end

      sig do
        params(
          class_or_proc: T.untyped, # constant name that should be loaded later upon use
          name: String, # name of command that will be used to key lookups
        ).void
      end
      def add(class_or_proc, name)
        commands[name] = class_or_proc
      end

      sig do
        params(name: T.nilable(String)) # candidate command name
          .returns([
            T.nilable(Class), # resolved command implementation class (or nil if none)
            String, # resolved name (different from input if input was e.g. an alias)
          ])
      end
      def lookup_command(name)
        name = @default if name.to_s.empty?
        resolve_command(name)
      end

      sig do
        params(
          from: String, # alias (short) name
          to:   String, # full command (long) name
        ).void
      end
      def add_alias(from, to)
        aliases[from] = to unless aliases[from]
      end

      sig { returns(T::Array[String]) }
      def command_names
        @contextual_resolver.command_names + commands.keys
      end

      sig do
        params(name: String) # command name or alias to check for presence of
          .returns(T::Boolean)
      end
      def exist?(name)
        cmd, = resolve_command(name)
        !cmd.nil?
      end

      private

      sig do
        params(name: String) # candidate alias (short) name
          .returns(String) # resolved command (long) name (or same as input if none)
      end
      def resolve_alias(name)
        aliases[name] || @contextual_resolver.aliases.fetch(name, name)
      end

      sig do
        params(name: String) # candidate command name
          .returns([
            T.nilable(Class), # resolved command implementation class (or nil if none)
            String, # resolved name (different from input if input was e.g. an alias)
          ])
      end
      def resolve_command(name)
        name = resolve_alias(name)
        resolve_global_command(name) || \
          resolve_contextual_command(name) || \
          [nil, name]
      end

      sig do
        params(name: String) # candidate command name
          .returns(T.nilable([
            T.nilable(Class), # resolved command implementation class (or nil if none)
            String, # resolved name (different from input if input was e.g. an alias)
          ]))
      end
      def resolve_global_command(name)
        klass = resolve_class(commands.fetch(name, nil))
        return nil unless klass&.defined?
        [klass, name]
      rescue NameError
        nil
      end

      sig do
        params(name: String) # candidate command name
          .returns(T.nilable([
            T.nilable(Class), # resolved command implementation class (or nil if none)
            String, # resolved name (different from input if input was e.g. an alias)
          ]))
      end
      def resolve_contextual_command(name)
        found = @contextual_resolver.command_names.include?(name)
        return nil unless found
        [@contextual_resolver.command_class(name), name]
      end

      sig do
        type_parameters(:U, :V)
          .params(class_or_proc: T.any(T.proc.returns(T.type_parameter(:U)), T.type_parameter(:V)))
          .returns(T.any(T.type_parameter(:U), T.type_parameter(:V)))
      end
      def resolve_class(class_or_proc)
        if class_or_proc.is_a?(Class)
          class_or_proc
        elsif class_or_proc.respond_to?(:call)
          class_or_proc.call
        else
          class_or_proc
        end
      end
    end
  end
end
