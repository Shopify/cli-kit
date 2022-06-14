require 'test_helper'

module CLI
  module Kit
    class OptsTest < Minitest::Test
      class TestOpts < CLI::Kit::Opts
        def force
          flag(short: '-f', long: '--force', desc: 'Force')
        end

        def output
          option!(short: '-o', long: '--output', default: 'text')
        end

        def file
          option(long: '--file')
        end

        def args
          rest
        end
      end

      module FirstMixin
        include(CLI::Kit::Opts::Mixin)

        def first
          position!
        end
      end

      module MixinMixin
        include(CLI::Kit::Opts::Mixin)

        def penultimate
          position!
        end
      end

      module LastMixin
        include(CLI::Kit::Opts::Mixin)
        include(MixinMixin)

        def last
          position!
        end
      end

      class OrderOpts < CLI::Kit::Opts
        include(FirstMixin)

        def middle
          position!
        end

        include(LastMixin)
      end

      class SkipOpts < CLI::Kit::Opts
        def first
          position(skip: -> { skip? }, default: 'default')
        end

        def second
          position(skip: ->(arg) { arg == 'skip' })
        end

        def third
          position!
        end

        def skip?
          flag(long: '--skip')
        end
      end

      class MultiDefaultOpts < CLI::Kit::Opts
        def multi
          multi_option(long: '--multi', default: -> { no_multi? ? [] : ['default'] })
        end

        def no_multi?
          flag(long: '--no-multi')
        end
      end

      def test_stuff
        opts = TestOpts.new
        defn = Args::Definition.new
        opts.define!(defn)
        evl = evaluate(defn, '-f -o json test -- a b')
        opts.evaluate!(evl)
        assert(opts.force)
        assert_equal('json', opts.output)
        refute(opts.file)
        assert_equal(['test'], opts.args)
        assert_equal(['a', 'b'], opts.unparsed)

        assert_equal({ output: 'json', file: nil }, opts.each_option.to_h)
        assert_equal({ force: true, help: false }, opts.each_flag.to_h)

        assert_equal('json', opts.lookup_option('output'))
        assert_equal(true, opts.lookup_flag('force'))

        refute(opts.lookup_option('force'))
        refute(opts.lookup_flag('output'))
        refute(opts.lookup_flag('foobar'))

        assert_equal('json', opts['output'])
        assert_equal(true, opts['force'])
      end

      def test_order
        defn = Args::Definition.new
        opts = OrderOpts.new
        opts.define!(defn)
        evl = evaluate(defn, 'a b c d')
        opts.evaluate!(evl)
        assert_equal('a', opts.first)
        assert_equal('b', opts.middle)
        assert_equal('c', opts.penultimate)
        assert_equal('d', opts.last)
      end

      def test_skip
        defn = Args::Definition.new
        opts = SkipOpts.new
        opts.define!(defn)
        evl = evaluate(defn, 'skip --skip')
        opts.evaluate!(evl)
        assert_equal('default', opts.first)
        assert_nil(opts.second)
        assert_equal('skip', opts.third)

        defn = Args::Definition.new
        opts = SkipOpts.new
        opts.define!(defn)
        evl = evaluate(defn, 'a b c')
        opts.evaluate!(evl)
        assert_equal('a', opts.first)
        assert_equal('b', opts.second)
        assert_equal('c', opts.third)
      end

      def test_multi_default
        opts = MultiDefaultOpts.new
        defn = Args::Definition.new
        opts.define!(defn)
        evl = evaluate(defn, '')
        opts.evaluate!(evl)
        assert_equal(['default'], opts.multi)

        defn = Args::Definition.new
        opts = MultiDefaultOpts.new
        opts.define!(defn)
        evl = evaluate(defn, '--no-multi')
        opts.evaluate!(evl)
        assert_equal([], opts.multi)

        defn = Args::Definition.new
        opts = MultiDefaultOpts.new
        opts.define!(defn)
        evl = evaluate(defn, '--multi a --multi b')
        opts.evaluate!(evl)
        assert_equal(['a', 'b'], opts.multi)
      end

      private

      def evaluate(defn, str)
        tokens = Args::Tokenizer.tokenize(str.split(' '))
        parse = Args::Parser.new(defn).parse(tokens)
        Args::Evaluation.new(defn, parse)
      end
    end
  end
end
