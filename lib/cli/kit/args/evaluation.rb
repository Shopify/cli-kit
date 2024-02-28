# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Evaluation
        extend T::Sig

        Error = Class.new(Args::Error)

        class MissingRequiredOption < Error
          extend T::Sig
          sig { params(name: String).void }
          def initialize(name)
            super("missing required option `#{name}'")
          end
        end

        class MissingRequiredPosition < Error
          extend T::Sig
          sig { void }
          def initialize
            super('more arguments required')
          end
        end

        class TooManyPositions < Error
          extend T::Sig
          sig { void }
          def initialize
            super('too many arguments')
          end
        end

        class FlagProxy
          extend T::Sig

          sig { params(sym: Symbol).returns(T::Boolean) }
          def method_missing(sym)
            flag = @evaluation.defn.lookup_flag(sym)
            unless flag
              raise NoMethodError, "undefined flag `#{sym}' for #{self}"
            end

            @evaluation.send(:lookup_flag, flag)
          end

          sig { params(sym: Symbol, include_private: T::Boolean).returns(T::Boolean) }
          def respond_to_missing?(sym, include_private = false)
            !!@evaluation.defn.lookup_flag(sym)
          end

          sig { params(evaluation: Evaluation).void }
          def initialize(evaluation)
            @evaluation = evaluation
          end
        end

        class OptionProxy
          extend T::Sig

          sig { params(sym: Symbol).returns(T.any(NilClass, String, T::Array[String])) }
          def method_missing(sym)
            opt = @evaluation.defn.lookup_option(sym)
            unless opt
              raise NoMethodError, "undefined option `#{sym}' for #{self}"
            end

            @evaluation.send(:lookup_option, opt)
          end

          sig { params(sym: Symbol, include_private: T::Boolean).returns(T::Boolean) }
          def respond_to_missing?(sym, include_private = false)
            !!@evaluation.defn.lookup_option(sym)
          end

          sig { params(evaluation: Evaluation).void }
          def initialize(evaluation)
            @evaluation = evaluation
          end
        end

        class PositionProxy
          extend T::Sig

          sig { params(sym: Symbol).returns(T.any(NilClass, String, T::Array[String])) }
          def method_missing(sym)
            position = @evaluation.defn.lookup_position(sym)
            unless position
              raise NoMethodError, "undefined position `#{sym}' for #{self}"
            end

            @evaluation.send(:lookup_position, position)
          end

          sig { params(sym: Symbol, include_private: T::Boolean).returns(T::Boolean) }
          def respond_to_missing?(sym, include_private = false)
            !!@evaluation.defn.lookup_position(sym)
          end

          sig { params(evaluation: Evaluation).void }
          def initialize(evaluation)
            @evaluation = evaluation
          end
        end

        sig { returns(FlagProxy) }
        def flag
          @flag_proxy ||= FlagProxy.new(self)
        end

        sig { returns(OptionProxy) }
        def opt
          @option_proxy ||= OptionProxy.new(self)
        end

        sig { returns(PositionProxy) }
        def position
          @position_proxy ||= PositionProxy.new(self)
        end

        sig { returns(Definition) }
        attr_reader :defn

        sig { returns(T::Array[Parser::Node]) }
        attr_reader :parse

        sig { returns(T::Array[String]) }
        def unparsed
          @unparsed ||= begin
            nodes = T.cast(
              parse.select { |node| node.is_a?(Parser::Node::Unparsed) },
              T::Array[Parser::Node::Unparsed],
            )
            nodes.flat_map(&:value)
          end
        end

        sig { params(defn: Definition, parse: T::Array[Parser::Node]).void }
        def initialize(defn, parse)
          @defn = defn
          @parse = parse
          check_required_options!
        end

        sig { void }
        def check_required_options!
          @defn.options.each do |opt|
            next unless opt.required?

            node = @parse.detect do |node|
              node.is_a?(Parser::Node::Option) && node.name.to_sym == opt.name
            end
            if !node || T.cast(node, Parser::Node::Option).value.nil?
              raise(MissingRequiredOption, opt.as_written_by_user)
            end
          end
        end

        sig { void }
        def resolve_positions!
          args_i = 0
          @position_values = Hash.new
          @defn.positions.each do |position|
            raise(MissingRequiredPosition) if position.required? && args_i >= args.size
            next if args_i >= args.size || position.skip?(T.must(args[args_i]))

            if position.multi?
              @position_values[position.name] = args[args_i..]
              args_i = args.size
            else
              @position_values[position.name] = T.must(args[args_i])
              args_i += 1
            end
          end
          raise(TooManyPositions) if args_i < args.size
        end

        sig { params(flag: Definition::Flag).returns(T::Boolean) }
        def lookup_flag(flag)
          if flag.short
            flags = T.cast(
              parse.select { |node| node.is_a?(Parser::Node::ShortFlag) },
              T::Array[Parser::Node::ShortFlag],
            )
            return true if flags.any? { |node| node.value == flag.short }
          end
          if flag.long
            flags = T.cast(
              parse.select { |node| node.is_a?(Parser::Node::LongFlag) },
              T::Array[Parser::Node::LongFlag],
            )
            return true if flags.any? { |node| node.value == flag.long }
          end
          false
        end

        sig { params(opt: Definition::Option).returns(T.any(NilClass, String, T::Array[String])) }
        def lookup_option(opt)
          opts = T.cast(
            parse.select { |node| node.is_a?(Parser::Node::ShortOption) || node.is_a?(Parser::Node::LongOption) },
            T::Array[T.any(Parser::Node::ShortOption, Parser::Node::LongOption)],
          )
          matches = opts.select { |node| (opt.short && node.name == opt.short) || (opt.long && node.name == opt.long) }
          if (last = matches.last)
            return(opt.multi? ? matches.map(&:value) : last.value)
          end

          opt.default
        end

        sig { params(position: Definition::Position).returns(T.any(NilClass, String, T::Array[String])) }
        def lookup_position(position)
          @position_values.fetch(position.name) { position.multi? ? [] : position.default }
        end

        private

        sig { returns(T::Array[String]) }
        def args
          @args ||= begin
            nodes = T.cast(
              parse.select { |node| node.is_a?(Parser::Node::Argument) },
              T::Array[Parser::Node::Argument],
            )
            nodes.map(&:value)
          end
        end
      end
    end
  end
end
