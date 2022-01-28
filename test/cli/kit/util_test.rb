require 'test_helper'

module CLI
  module Kit
    class UtilTest < Minitest::Test
      def test_to_filesize
        assert_equal('0B', CLI::Kit::Util.to_filesize(0))
        assert_equal('0 B',  CLI::Kit::Util.to_filesize(0, space: true))

        assert_equal('10B',  CLI::Kit::Util.to_filesize(10 * 1024**0))
        assert_equal('10kB',  CLI::Kit::Util.to_filesize(10 * 1024**1))
        assert_equal('10MB',  CLI::Kit::Util.to_filesize(10 * 1024**2))
        assert_equal('10GB',  CLI::Kit::Util.to_filesize(10 * 1024**3))
        assert_equal('10TB',  CLI::Kit::Util.to_filesize(10 * 1024**4))

        # Float behavior
        assert_equal('12.9kB',  CLI::Kit::Util.to_filesize(13_212))
        assert_equal('126.0MB', CLI::Kit::Util.to_filesize(132_121_322))
        assert_equal('1.23GB',  CLI::Kit::Util.to_filesize(1_321_213_212))
        assert_equal('-10.5kB', CLI::Kit::Util.to_filesize(-10.5 * 1024**1))
      end

      # Extra tests for edge cases of to_si_scale
      def test_to_si_scale
        assert_equal('-1ms', CLI::Kit::Util.to_si_scale(-0.001, 's'))
        assert_equal('1ms', CLI::Kit::Util.to_si_scale(0.001, 's'))
        assert_equal('123ms', CLI::Kit::Util.to_si_scale(0.123, 's'))
        assert_equal('123.4µs', CLI::Kit::Util.to_si_scale(0.0001234, 's'))

        assert_equal('1.0s', CLI::Kit::Util.to_si_scale(1.001, 's'))
        assert_equal('1.001s', CLI::Kit::Util.to_si_scale(1.0012, 's', precision: 3))

        assert_equal('10k', CLI::Kit::Util.to_si_scale(10_000))
        assert_equal('10 km', CLI::Kit::Util.to_si_scale(10_000, 'm', space: true))

        assert_raises(ArgumentError) do
          CLI::Kit::Util.to_si_scale(0, '', factor: 10)
        end
      end
    end
  end
end
