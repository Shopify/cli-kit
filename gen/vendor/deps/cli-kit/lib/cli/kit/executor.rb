require 'cli/kit'
require 'English'

module CLI
  module Kit
    class Executor
      def initialize(
        tool_name:, command_registry:, error_handler:, log_file: nil
      )
        @tool_name = tool_name
        @command_registry = command_registry
        @error_handler = error_handler
        @log_file = log_file
      end

      def with_logging(&block)
        return yield unless @log_file
        CLI::UI.log_output_to(@log_file, &block)
      end

      def commands_and_aliases
        @command_registry.command_names + @command_registry.aliases.keys
      end

      def trap_signals
        trap('QUIT') do
          z = caller
          CLI::UI.raw do
            STDERR.puts('SIGQUIT: quit')
            STDERR.puts(z)
          end
          exit 1
        end
        trap('INFO') do
          z = caller
          CLI::UI.raw do
            STDERR.puts('SIGINFO:')
            STDERR.puts(z)
            # Thread.list.map { |t| t.backtrace }
          end
        end
      end

      def call(command, command_name, args)
        trap_signals
        with_logging do
          @error_handler.handle_abort do
            if command.nil?
              command_not_found(command_name)
              raise CLI::Kit::AbortSilent # Already output message
            end
            command.call(args, command_name)
            CLI::Kit::EXIT_SUCCESS # unless an exception was raised
          end
        end
      end

      def command_not_found(name)
        CLI::UI::Frame.open("Command not found", color: :red, timing: false) do
          STDERR.puts(CLI::UI.fmt("{{command:#{@tool_name} #{name}}} was not found"))
        end

        cmds = commands_and_aliases
        if cmds.all? { |cmd| cmd.is_a?(String) }
          possible_matches = cmds.min_by(2) do |cmd|
            CLI::Kit::Levenshtein.distance(cmd, name)
          end

          # We don't want to match against any possible command
          # so reject anything that is too far away
          possible_matches.reject! do |possible_match|
            CLI::Kit::Levenshtein.distance(possible_match, name) > 3
          end

          # If we have any matches left, tell the user
          if possible_matches.any?
            CLI::UI::Frame.open("{{bold:Did you mean?}}", timing: false, color: :blue) do
              possible_matches.each do |possible_match|
                STDERR.puts CLI::UI.fmt("{{command:#{@tool_name} #{possible_match}}}")
              end
            end
          end
        end
      end
    end
  end
end
