require 'test_helper'

module CLI
  module Kit
    module Args
      class EvaluationTest < Minitest::Test
        Node = Parser::Node

        def setup
          @defn = Args::Definition.new
          @defn.add_flag(:f, short: '-f', long: '--force')
          @defn.add_option(:zk, short: '-z', long: '--zookeeper')
          @defn.add_option(:height, long: '--height')
          @defn.add_option(:w, long: '--w')
          @defn.add_flag(:print, long: '--print')
          @defn.add_flag(:verbose, long: '--verbose')
          @defn.add_option(:output, short: '-o', default: 'text')
          @defn.add_option(:multi_default, short: '-m', multi: true, default: ['a'])
          @defn.add_option(:notprovided, short: '-n')
          @defn.add_position(:first, required: true, multi: false)
          @defn.add_position(:second, required: false, multi: false, skip: ->(arg) { arg == 'b' })
          @defn.add_position(:third, required: false, multi: false, skip: ->(arg) { arg != 'b' })
          @defn.add_position(:rest, required: false, multi: true)

          @parse = [
            Node::ShortFlag.new('f'),
            Node::ShortOption.new('z', '200'),
            Node::LongOption.new('height', '3'),
            Node::LongOption.new('w', '4'),
            Node::Argument.new('a'),
            Node::Argument.new('b'),
            Node::Argument.new('c'),
            Node::Argument.new('d'),
            Node::LongFlag.new('print'),
            Node::Unparsed.new(['d', '--neato', '-f']),
          ]
        end

        def test_evaluation
          evl = Evaluation.new(@defn, @parse)
          evl.resolve_positions!
          assert(evl.flag.f)
          assert(evl.flag.print)
          refute(evl.flag.verbose)
          assert_equal('200', evl.opt.zk)
          assert_equal('3', evl.opt.height)
          assert_equal('text', evl.opt.output)
          assert_equal(['a'], evl.opt.multi_default)
          refute(evl.opt.notprovided)
          assert_raises(NameError) { evl.opt.foobar }
          assert_raises(NameError) { evl.flag.foobar }
          refute(evl.flag.respond_to?(:foobar))
          refute(evl.opt.respond_to?(:foobar))
          assert(evl.flag.respond_to?(:f))
          assert(evl.opt.respond_to?(:height))
          assert_equal('a', evl.position.first)
          assert_nil(evl.position.second)
          assert_equal('b', evl.position.third)
          assert_equal(['c', 'd'], evl.position.rest)
          assert_equal(['d', '--neato', '-f'], evl.unparsed)
        end

        def test_evaluation_required
          @defn.add_option(:req, short: '-r', required: true)
          assert_raises(Evaluation::MissingRequiredOption) do
            Evaluation.new(@defn, @parse)
          end
        end
      end
    end
  end
end
