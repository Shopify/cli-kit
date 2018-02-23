require 'test_helper'

module CLI
  module Kit
    class ResolverTest < MiniTest::Test
      attr_reader :reg, :res
      def setup
        @reg = CommandRegistry.new(default: 'help', contextual_resolver: nil)
        @res = Resolver.new(tool_name: 'tool', command_registry: reg)
      end

      def test_resolver_no_match
        _, err = capture_io do
          assert_raises(CLI::Kit::AbortSilent) do
            res.call(['foo'])
          end
        end
        assert_match(/tool foo.* was not found/, err)
      end

      def test_more
        skip
      end
    end
  end
end
