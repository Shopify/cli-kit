require 'cli/kit'

module CLI
  module Kit
    class Help
      class Output
        def initialize(out, tty)
          @out = out
          @tty = tty
        end

        def puts(str = "", indent: 0)
          @out.puts("#{' ' * indent}#{CLI::UI.fmt(str, enable_color: @tty)}")
        end
      end
    end
  end
end
