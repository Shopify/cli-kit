# typed: true

require 'cli/kit'

module CLI
  module Kit
    module CommandHelp
      extend T::Sig
      include Kernel # for sorbet

      sig { params(args: T::Array[String], name: String).void }
      def call(args, name)
        begin
          opts = self.class.opts_class
          opts_inst = opts.new
          defn = Args::Definition.new
          opts_inst.define!(defn)
          tokens = Args::Tokenizer.tokenize(args)
          parse = Args::Parser.new(defn).parse(tokens)
          evl = Args::Evaluation.new(defn, parse)
          opts_inst.evaluate!(evl)
        rescue Args::Evaluation::TooManyPositions, Args::Evaluation::MissingRequiredPosition => e
          STDERR.puts CLI::UI.fmt("{{red:{{bold:Error: #{e.message}}}}}")
          STDERR.puts
          STDERR.puts self.class.build_help
          raise(AbortSilent)
        rescue Args::Error => e
          raise(Abort, e)
        end

        if opts_inst.helpflag
          puts self.class.build_help
        else
          invoke_wrapper(opts_inst, name)
        end
      end

      # use to implement error handling
      sig { params(op: T.untyped, name: String).void }
      def invoke_wrapper(op, name)
        invoke(op, name)
      end

      sig { params(op: T.untyped, name: String).void }
      def invoke(op, name)
        raise(NotImplementedError, '#invoke must be implemented, or #call overridden')
      end

      class << self
        extend T::Sig

        sig { params(tool_name: String).void }
        attr_writer :tool_name

        sig { params(max_desc_length: Integer).void }
        attr_writer :max_desc_length

        sig { returns(String) }
        def _tool_name
          unless @tool_name
            raise 'You must set CLI::Kit::CommandHelp.tool_name='
          end

          @tool_name
        end

        sig { returns(Integer) }
        def _max_desc_length
          @max_desc_length || 80
        end
      end

      module ClassMethods
        extend T::Sig
        include Kernel # for sorbet

        DEFAULT_HELP_SECTIONS = [
          :desc,
          :long_desc,
          :usage,
          :examples,
          :options,
        ]

        sig { returns(String) }
        def build_help
          h = (@help_sections || DEFAULT_HELP_SECTIONS).map do |section|
            case section
            when :desc
              build_desc
            when :long_desc
              @long_desc
            when :usage
              @usage_section ||= build_usage
            when :examples
              @examples_section ||= build_examples
            when :options
              @options_section ||= build_options
            else
              raise "Unknown help section: #{section}"
            end
          end.compact.map(&:chomp).join("\n\n") + "\n"
          CLI::UI.fmt(h)
        end

        sig { returns(String) }
        def _command_name
          return @command_name if @command_name

          last_camel = send(:name).split('::').last
          last_camel.gsub(/([a-z])([A-Z])/, '\1-\2').downcase
        end

        sig { returns(String) }
        def _desc
          @desc
        end

        sig { returns(String) }
        def build_desc
          out = +"{{command:#{CommandHelp._tool_name} #{_command_name}}}"
          if @desc
            out << ": #{@desc}"
          end
          "{{bold:#{out}}}"
        end

        sig { returns(T.untyped) }
        def opts_class
          T.unsafe(self).const_get(:Opts) # rubocop:disable Sorbet/ConstantsFromStrings
        rescue NameError
          Class.new(CLI::Kit::Opts)
        end

        sig { returns(T.nilable(String)) }
        def build_options
          opts = opts_class
          return(nil) unless opts

          methods = []
          loop do
            methods.concat(opts.public_instance_methods(false))
            break if opts.superclass == CLI::Kit::Opts

            opts = opts.superclass
          end

          @defn = Args::Definition.new
          o = opts.new
          o.define!(@defn)

          return if @defn.options.empty? && @defn.flags.empty?

          merged = T.let(@defn.options, T::Array[T.any(Args::Definition::Option, Args::Definition::Flag)])
          merged += @defn.flags
          merged.sort_by!(&:name)
          "{{bold:Options:}}\n" + merged.map do |o|
            if o.is_a?(Args::Definition::Option)
              z = '  ' + [o.short&.prepend('-'), o.long&.prepend('--')].compact.join(', ') + ' VALUE'
              default = if o.dynamic_default?
                '(generated default)'
              elsif o.default.nil?
                '(no default)'
              else
                "(default: #{o.default.inspect})"
              end
              z << if o.desc
                "  {{italic:{{gray:# #{o.desc} #{default}}}}}"
              else
                "  {{italic:{{gray:# #{default}}}}}"
              end
            else
              z = '  ' + [o.short&.prepend('-'), o.long&.prepend('--')].compact.join(', ')
              if o.desc
                z << "  {{italic:{{gray:# #{o.desc}}}}}"
              end
            end
            z
          end.join("\n")
        end

        sig { params(sections: T::Array[Symbol]).void }
        def help_sections(sections)
          @help_sections = sections
        end

        sig { params(command_name: String).void }
        def command_name(command_name)
          if @command_name
            raise(ArgumentError, "Command name already set to #{@command_name}")
          end

          @command_name = command_name
        end

        sig { params(desc: String).void }
        def desc(desc)
          # A limit of 80 characters has been chosen to fit on standard terminal configurations. `long_desc` is
          # available when descriptions don't fit nicely in that space. If you're using CLI::Kit for an application
          # where you control the runtime environments and know that terminals will have more than 80 columns
          # available, you can use
          #
          #   CLI::Kit::CommandHelp.max_desc_length =
          #
          # to increase this limit.
          if desc.size > CommandHelp._max_desc_length
            raise(ArgumentError, "description must be #{CommandHelp._max_desc_length} characters or less")
          end
          if @desc
            raise(ArgumentError, 'description already set')
          end

          @desc = desc
        end

        sig { params(long_desc: String).void }
        def long_desc(long_desc)
          if @long_desc
            raise(ArgumentError, 'long description already set')
          end

          @long_desc = long_desc
        end

        sig { returns(String) }
        def build_usage
          '{{bold:Usage:}}' + case (@usage || []).size
          when 0
            " {{command:#{CommandHelp._tool_name} #{_command_name}}} [options]\n"
          when 1
            " {{command:#{CommandHelp._tool_name} #{_command_name}}} #{@usage.first}\n"
          else
            "\n" + @usage.map do |usage|
              "  {{command:#{CommandHelp._tool_name} #{_command_name}}} #{usage}\n"
            end.join
          end
        end

        sig { returns(T.nilable(String)) }
        def build_examples
          return unless @examples

          cmd_prefix = "  {{command:#{CommandHelp._tool_name} #{_command_name}}}"
          "{{bold:Examples:}}\n" + @examples.map do |command, explanation|
            cmd = "#{cmd_prefix} #{command}"
            exp = "{{italic:{{gray:# #{explanation}}}}}"

            width = CLI::UI::ANSI.printing_width(CLI::UI.fmt("#{cmd} #{exp}"))
            if width > CLI::UI::Terminal.width
              "  #{exp}\n#{cmd}"
            else
              "#{cmd}  #{exp}"
            end
          end.join("\n\n")
        end

        sig { params(usage: String).void }
        def usage(usage)
          @usage ||= []
          @usage << usage
        end

        sig { params(command: String, explanation: T.nilable(String)).void }
        def example(command, explanation)
          @examples ||= []
          @examples << [command, explanation]
        end
      end
    end
  end
end
