require 'test_helper'

module CLI
  module Kit
    module Args
      class DefinitionTest < Minitest::Test
        Flag = Definition::Flag
        Option = Definition::Option

        def test_simple
          defn = Definition.new
          defn.add_flag(:force, short: '-f')
          assert_equal('f', defn.lookup_flag(:force).short)
          refute(defn.lookup_option(:force))
        end

        def test_conflict
          defn = Definition.new
          defn.add_flag(:version, short: '-v')
          assert_raises(Definition::ConflictingFlag) do
            defn.add_flag(:verbose, short: '-v', long: '--verbose')
          end
          assert_raises(Definition::ConflictingFlag) do
            defn.add_option(:vertical, short: '-v', long: '--vertical')
          end
          defn.add_option(:height, short: '-h', long: '--height')
          assert_raises(Definition::ConflictingFlag) do
            defn.add_option(:height2, long: '--height')
          end
          assert_raises(Definition::ConflictingFlag) do
            defn.add_option(:height, long: '--something')
          end
        end

        def test_invalid_flags
          defn = Definition.new
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, short: '-ab')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, short: '--a')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, short: 'a')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, short: '--')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, long: '-a')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, long: '---a')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, long: '--')
          end
          assert_raises(Definition::InvalidFlag) do
            defn.add_flag(:invalid, long: 'a')
          end
        end

        def test_short_or_long_required
          defn = Definition.new
          assert_raises(Definition::Error) do
            defn.add_flag(:invalid)
          end
        end

        def test_lookup
          defn = Definition.new
          defn.add_flag(:force, short: '-f')
          defn.add_option(:height, short: '-h', long: '--height')
          assert_equal(:height, defn.lookup_long('height').name)
          assert_equal(:height, defn.lookup_short('h').name)
          assert_equal(:force, defn.lookup_short('f').name)
          refute(defn.lookup_long('f'))
          refute(defn.lookup_short('height'))

          # - prefixes invalid
          assert_raises(Definition::InvalidLookup) { defn.lookup_long('--b') }
          assert_raises(Definition::InvalidLookup) { defn.lookup_long('-b') }
        end
      end
    end
  end
end
