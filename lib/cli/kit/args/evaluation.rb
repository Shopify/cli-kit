# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Evaluation
        Error = Class.new(Args::Error)

        class MissingRequiredOption < Error
          #: (String name) -> void
          def initialize(name)
            super("missing required option `#{name}'")
          end
        end

        class MissingRequiredPosition < Error
          #: -> void
          def initialize
            super('more arguments required')
          end
        end

        class TooManyPositions < Error
          #: -> void
          def initialize
            super('too many arguments')
          end
        end

        class FlagProxy
          #: (Symbol sym) -> bool
          def method_missing(sym)
            flag = @evaluation.defn.lookup_flag(sym)
            unless flag
              raise NoMethodError, "undefined flag `#{sym}' for #{self}"
            end

            @evaluation.send(:lookup_flag, flag)
          end

          #: (Symbol sym, ?bool include_private) -> bool
          def respond_to_missing?(sym, include_private = false)
            !!@evaluation.defn.lookup_flag(sym)
          end

          #: (Evaluation evaluation) -> void
          def initialize(evaluation)
            @evaluation = evaluation
          end
        end

        class OptionProxy
          #: (Symbol sym) -> (String | Array[String])?
          def method_missing(sym)
            opt = @evaluation.defn.lookup_option(sym)
            unless opt
              raise NoMethodError, "undefined option `#{sym}' for #{self}"
            end

            @evaluation.send(:lookup_option, opt)
          end

          #: (Symbol sym, ?bool include_private) -> bool
          def respond_to_missing?(sym, include_private = false)
            !!@evaluation.defn.lookup_option(sym)
          end

          #: (Evaluation evaluation) -> void
          def initialize(evaluation)
            @evaluation = evaluation
          end
        end

        class PositionProxy
          #: (Symbol sym) -> (String | Array[String])?
          def method_missing(sym)
            position = @evaluation.defn.lookup_position(sym)
            unless position
              raise NoMethodError, "undefined position `#{sym}' for #{self}"
            end

            @evaluation.send(:lookup_position, position)
          end

          #: (Symbol sym, ?bool include_private) -> bool
          def respond_to_missing?(sym, include_private = false)
            !!@evaluation.defn.lookup_position(sym)
          end

          #: (Evaluation evaluation) -> void
          def initialize(evaluation)
            @evaluation = evaluation
          end
        end

        #: -> FlagProxy
        def flag
          @flag_proxy ||= FlagProxy.new(self)
        end

        #: -> OptionProxy
        def opt
          @option_proxy ||= OptionProxy.new(self)
        end

        #: -> PositionProxy
        def position
          @position_proxy ||= PositionProxy.new(self)
        end

        #: Definition
        attr_reader :defn

        #: Array[Parser::Node]
        attr_reader :parse

        #: -> Array[String]
        def unparsed
          @unparsed ||= begin
            nodes = parse.select { |node| node.is_a?(Parser::Node::Unparsed) } #: as Array[Parser::Node::Unparsed]
            nodes.flat_map(&:value)
          end
        end

        #: (Definition defn, Array[Parser::Node] parse) -> void
        def initialize(defn, parse)
          @defn = defn
          @parse = parse
          check_required_options!
        end

        #: -> void
        def check_required_options!
          @defn.options.each do |opt|
            next unless opt.required?

            node = @parse.detect do |node|
              node.is_a?(Parser::Node::Option) && node.name.to_sym == opt.name
            end
            unless node
              raise(MissingRequiredOption, opt.as_written_by_user)
            end

            node = node #: as Parser::Node::Option
            if node.value.nil?
              raise(MissingRequiredOption, opt.as_written_by_user)
            end
          end
        end

        #: -> void
        def resolve_positions!
          args_i = 0
          @position_values = Hash.new
          @defn.positions.each do |position|
            raise(MissingRequiredPosition) if position.required? && args_i >= args.size
            next if args_i >= args.size || position.skip?(
              args[args_i], #: as !nil
            )

            if position.multi?
              @position_values[position.name] = args[args_i..]
              args_i = args.size
            else
              @position_values[position.name] = args[args_i] #: as !nil
              args_i += 1
            end
          end
          raise(TooManyPositions) if args_i < args.size
        end

        #: (Definition::Flag flag) -> bool
        def lookup_flag(flag)
          if flag.short
            flags = parse.select { |node| node.is_a?(Parser::Node::ShortFlag) } #: as Array[Parser::Node::ShortFlag]
            return true if flags.any? { |node| node.value == flag.short }
          end
          if flag.long
            flags = parse.select { |node| node.is_a?(Parser::Node::LongFlag) } #: as Array[Parser::Node::LongFlag]
            return true if flags.any? { |node| node.value == flag.long }
          end
          false
        end

        #: (Definition::Option opt) -> (String | Array[String])?
        def lookup_option(opt)
          opts = parse.select { |node| node.is_a?(Parser::Node::ShortOption) || node.is_a?(Parser::Node::LongOption) } #: as Array[Parser::Node::ShortOption | Parser::Node::LongOption]
          matches = opts.select { |node| (opt.short && node.name == opt.short) || (opt.long && node.name == opt.long) }
          if (last = matches.last)
            return (opt.multi? ? matches.map(&:value) : last.value)
          end

          opt.default
        end

        #: (Definition::Position position) -> (String | Array[String])?
        def lookup_position(position)
          @position_values.fetch(position.name) { position.multi? ? [] : position.default }
        end

        private

        #: -> Array[String]
        def args
          @args ||= begin
            nodes = parse.select { |node| node.is_a?(Parser::Node::Argument) } #: as Array[Parser::Node::Argument]
            nodes.map(&:value)
          end
        end
      end
    end
  end
end
