require 'cli/kit'

module CLI
  module Kit
    class Help
      class Command
        def initialize(out, f)
          @f = f
          @out = out
        end

        def render(command_name: raise, command: raise, indent: 0, list_all: false)
          syntax = @f.format_syntax(command['syntax'])
          prefix = !list_all ? 'Usage:' : ''
          @out.puts(
            "#{prefix} #{@f.lit CLI::Kit.tool_name} #{@f.cmd command_name} #{syntax}".strip,
            indent: indent
          )

          description(command_name, command, indent: indent + 2, list_all: list_all)
          long_description(command, indent: indent + 2) unless list_all
          flags(command, indent: indent + 2)
          subcommands(command_name, command, indent: indent + 2, list_all: list_all)
        end

        private

        def description(command_name, command, indent: raise, list_all: raise)
          description = command['desc'] || "(no description)"
          if list_all
            @out.puts(description.lines.first, indent: indent)

            # If we have more than one line in the description, or if a long_desc was provided
            # prompt the user to run a more specific command for more info
            #
            if description.lines.size > 1 || command['long_desc']
              @out.puts(
                "\u{2139} {{italic:Run {{command:#{CLI::Kit.tool_name} help #{command_name}}} "\
                  "for more info...}}",
                indent: indent
              )
            end
          else
            @out.puts('')
            @out.puts(description, indent: indent)
          end
          @out.puts('')
        end

        def long_description(command, indent: raise)
          return unless command['long_desc']

          command['long_desc'].lines.each do |line|
            @out.puts(line, indent: indent)
          end
          @out.puts('')
        end

        def flags(command, indent: raise)
          return unless command['flags']

          command['flags'].each do |fname, desc|
            @out.puts("#{@f.flag fname} #{desc}", indent: indent)
          end
          @out.puts('')
        end

        def subcommands(command_name, command, indent: raise, list_all: raise)
          return unless command['subcommands']

          # Usage for Subcommands
          @out.puts(
            "{{bold:Subcommands}}: \e[3m(#{CLI::Kit.tool_name} help #{command_name} <subcommand>)\e[0m",
            indent: indent
          )
          @out.puts('')

          # Render all subcommands
          command['subcommands'].each do |sub_command_name, sub_cmd|
            render(
              command_name: [command_name, sub_command_name].join(' '),
              command:      sub_cmd,
              indent:       indent,
              list_all:     list_all
            )
          end
        end
      end
    end
  end
end
