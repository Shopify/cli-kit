require 'test_helper'
require 'English'

module CLI
  module Kit
    class UtilTest < MiniTest::Test
      def test_snake_case
        assert_equal '', CLI::Kit::Util.snake_case('')
        assert_equal 'a', CLI::Kit::Util.snake_case('A')
        assert_equal 'aa', CLI::Kit::Util.snake_case('AA')
        assert_equal 'a', CLI::Kit::Util.snake_case('a')
        assert_equal 'foo/bar_b', CLI::Kit::Util.snake_case('Foo::BarB')
      end

      def test_to_filesize
        assert_equal '12.9KB',  CLI::Kit::Util.to_filesize(13212)
        assert_equal '126.0MB', CLI::Kit::Util.to_filesize(132121322)
        assert_equal '1.23GB',  CLI::Kit::Util.to_filesize(1321213212)
        assert_equal '12.02TB', CLI::Kit::Util.to_filesize(13212132121999)
      end
    end
  end
end
