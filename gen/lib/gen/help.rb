# typed: true

require 'gen'

module Gen
  module Help
    extend T::Sig

    class << self
      extend T::Sig

      sig { params(path: T::Array[String], to: IO).void }
      def generate(path, to: STDOUT)
        case path.size
        when 0
          generate_toplevel(to: to)
        when 1
          generate_command_help(T.must(path.first), to: to)
        else
          raise(NotImplementedError, 'subcommand help not implemented')
        end
      end

      sig { params(to: IO).void }
      def generate_toplevel(to: STDOUT)
        to.write(CLI::UI.fmt(<<~HELP))
          {{bold:{{command:cli-kit}} generates new cli-kit apps.}}

          It basically only has one command: {{command:cli-kit new}}.

          See {{command:cli-kit new --help}} for more information.

          {{bold:Available commands:}}
        HELP

        cmds = Gen::Commands::Registry.resolved_commands.map do |name, klass|
          [name, klass._desc]
        end

        max_len = cmds.map(&:first).map(&:length).max

        cmds.each do |name, desc|
          to.write(CLI::UI.fmt("  {{command:#{name.ljust(T.must(max_len))}}}  #{desc}\n"))
        end
      end

      sig { params(cmd_name: String, to: IO).void }
      def generate_command_help(cmd_name, to: STDOUT)
        klass = Gen::Commands::Registry.resolved_commands[cmd_name]
        unless klass
          to.write(CLI::UI.fmt(<<~HELP))
            {{red:{{bold:No help found for: #{cmd_name}}}}}

          HELP
          generate_toplevel(to: to)
          raise(CLI::Kit::AbortSilent)
        end

        klass.new.call(['--help'], cmd_name)
      end
    end
  end
end
