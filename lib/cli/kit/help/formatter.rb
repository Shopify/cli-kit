require 'cli/kit'

module CLI
  module Kit
    class Help
      class Formatter
        def lit(s)
          "{{green:#{s}}}"
        end

        def cmd(s)
          "{{cyan:#{s}}}"
        end

        def arg(s)
          "{{yellow:<#{s}>}}"
        end

        def opt(s)
          "{{cyan:[#{s}]}}"
        end

        def alt
          "{{cyan:|}}"
        end

        def bold(s)
          "{{bold:#{s}}}"
        end

        def flag(s)
          "{{cyan:--#{s}}}"
        end

        def error(s)
          "{{error:#{s}}}"
        end

        def format_syntax(ast)
          case ast
          when NilClass
            return ""
          when String
            return ast
          when Array
            return ast.map { |n| format_syntax(n) }
          when Hash
          else
            raise(CLI::Kit::Abort, "invalid AST type: #{ast.class}")
          end

          ast.map do |func, a|
            case func
            when /^optional/
              opt(format_syntax(a))
            when /^argument/
              arg(format_syntax(a))
            when /^command/
              cmd(format_syntax(a))
            when /^literal/
              lit(format_syntax(a))
            when /^alternate/
              arr = format_syntax(a)
              arr.join(alt)
            when /^flag/
              flag(a)
            else
              raise(CLI::Kit::Abort, "invalid syntax element: #{func}")
            end
          end.join(" ")
        end
      end
    end
  end
end
