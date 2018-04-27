require 'test_helper'

module __App__
  class ExampleTest < MiniTest::Test
    include CLI::Kit::Support::TestHelper

    def test_example
      CLI::Kit::System.fake("ls -al", stdout: "a\nb", success: true)
      assert_all_commands_run do
        out, = CLI::Kit::System.capture2('ls', '-al')
        assert_equal ['a', 'b'], out.split("\n")
      end
    end
  end
end
