require 'test_helper'

module Dev
  module Kit
    class SystemTest < MiniTest::Test
      def test_split_partial_characters_doesnt_split_single_byte_characters
        str = "ルビー is cool"

        assert_equal [str, ''], System.split_partial_characters(str)
      end

      def test_split_partial_characters_splits_partial_characters_with_multiple_bytes
        str = "ルビー".byteslice(0...-1) # => "ルビ\xE3\x83"

        data, trailing = System.split_partial_characters(str)

        assert_equal "ルビ", data
        assert_equal str, data + trailing
      end

      def test_split_partial_characters_splits_partial_characters_with_a_single_byte
        str = "ルビー".byteslice(0...-2) # => "ルビ\xE3"

        data, trailing = System.split_partial_characters(str)

        assert_equal "ルビ", data
        assert_equal str, data + trailing
      end

      def test_split_partial_characters_gives_up_without_error_for_bad_utf8
        str = "Hello\x83\x83\x83\x83\x83\x83\x83\x83"

        assert_equal [str, ''], System.split_partial_characters(str)
      end
    end
  end
end

