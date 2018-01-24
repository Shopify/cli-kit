require 'cli/kit'
require 'cli/ui'
require 'English'

module CLI
  module Kit
    class EntryPoint
      # Interface methods: You may want to implement these:

      def self.before_initialize(args)
        nil
      end

      def self.troubleshoot(e)
        nil
      end

      def self.log_file
        nil
      end

      # End Interface methods

      def self.call(args)
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

        before_initialize(args)

        new(args).call
      end

      def initialize(args)
        command_name = args.shift
        @args = args

        ret = self.class.handle_abort do
          @command, @command_name = lookup_command(command_name)
          :success
        end

        if ret != :success
          exit CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
        end
      end

      def lookup_command(name)
        CLI::Kit::CommandRegistry.registry_target.lookup_command(name)
      end

      def self.format_error_message(msg)
        CLI::UI.fmt("{{red:#{msg}}}")
      end

      def self.handle_abort
        yield
      rescue CLI::Kit::GenericAbort => e
        is_bug    = e.is_a?(CLI::Kit::Bug) || e.is_a?(CLI::Kit::BugSilent)
        is_silent = e.is_a?(CLI::Kit::AbortSilent) || e.is_a?(CLI::Kit::BugSilent)

        if !is_silent && ENV['IM_ALREADY_PRO_THANKS'].nil?
          troubleshoot(e)
        elsif !is_silent
          STDERR.puts(format_error_message(e.message))
        end

        if is_bug
          CLI::Kit::ReportErrors.exception = e
        end

        return CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      rescue Interrupt
        STDERR.puts(format_error_message("Interrupt"))
        return CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end

      def with_logging(log_file, &block)
        return yield unless log_file
        CLI::UI.log_output_to(log_file, &block)
      end

      def self.commands_and_aliases
        reg = CLI::Kit::CommandRegistry.registry_target
        reg.command_names + reg.aliases.keys
      end

      def call
        with_logging(self.class.log_file) do
          self.class.handle_abort do
            if @command.nil?
              CLI::UI::Frame.open("Command not found", color: :red, timing: false) do
                STDERR.puts(CLI::UI.fmt("{{command:#{CLI::Kit.tool_name} #{@command_name}}} was not found"))
              end

              cmds = self.class.commands_and_aliases
              if cmds.all? { |cmd| cmd.is_a?(String) }
                possible_matches = cmds.min_by(2) do |cmd|
                  CLI::Kit::Levenshtein.distance(cmd, @command_name)
                end

                # We don't want to match against any possible command
                # so reject anything that is too far away
                possible_matches.reject! do |possible_match|
                  CLI::Kit::Levenshtein.distance(possible_match, @command_name) > 3
                end

                # If we have any matches left, tell the user
                if possible_matches.any?
                  CLI::UI::Frame.open("{{bold:Did you mean?}}", timing: false, color: :blue) do
                    possible_matches.each do |possible_match|
                      STDERR.puts CLI::UI.fmt("{{command:#{CLI::Kit.tool_name} #{possible_match}}}")
                    end
                  end
                end
              end

              raise CLI::Kit::AbortSilent # Already output message
            end

            @command.call(@args, @command_name)
            CLI::Kit::EXIT_SUCCESS # unless an exception was raised
          end
        end
      end
    end
  end
end
