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
          @defn.add_option(:notprovided, short: '-n')

          @parse = [
            Node::ShortFlag.new('f'),
            Node::ShortOption.new('z', '200'),
            Node::LongOption.new('height', '3'),
            Node::LongOption.new('w', '4'),
            Node::Argument.new('a'),
            Node::Argument.new('b'),
            Node::Argument.new('c'),
            Node::LongFlag.new('print'),
            Node::Rest.new(['d', '--neato', '-f']),
          ]
        end

        def test_evaluation
          evl = Evaluation.new(@defn, @parse)
          assert(evl.flag.f)
          assert(evl.flag.print)
          refute(evl.flag.verbose)
          assert_equal('200', evl.opt.zk)
          assert_equal('3', evl.opt.height)
          assert_equal('text', evl.opt.output)
          refute(evl.opt.notprovided)
          assert_raises(NameError) { evl.opt.foobar }
          assert_raises(NameError) { evl.flag.foobar }
          refute(evl.flag.respond_to?(:foobar))
          refute(evl.opt.respond_to?(:foobar))
          assert(evl.flag.respond_to?(:f))
          assert(evl.opt.respond_to?(:height))
          assert_equal(['a', 'b', 'c'], evl.args)
          assert_equal(['d', '--neato', '-f'], evl.rest)
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
