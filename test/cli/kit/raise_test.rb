# typed: true
# frozen_string_literal: true

require('test_helper')

module CLI
  module Kit
    class RaiseTest < Minitest::Test
      def test_simple_case
        check(bug: true, silent: false, message: 'foo', klass: StandardError) do
          CLI::Kit.raise(StandardError, 'foo')
        end
      end

      def test_bug_false
        check(bug: false, silent: false, message: 'foo', klass: StandardError) do
          CLI::Kit.raise(StandardError, 'foo', bug: false)
        end
      end

      def test_silent_true
        check(bug: true, silent: true, message: 'foo', klass: StandardError) do
          CLI::Kit.raise(StandardError, 'foo', silent: true)
        end
      end

      def test_implied_runtime_error
        check(bug: true, silent: true, message: 'bar', klass: RuntimeError) do
          CLI::Kit.raise('bar', silent: true)
        end
      end

      private

      def check(bug: nil, silent: nil, message: nil, klass: nil, &block)
        exc = nil
        begin
          block.call
        rescue Exception => e # rubocop:disable Lint/RescueException
          exc = e
        end
        assert(exc)
        exc = T.must(exc)
        assert_equal(bug, exc.bug?) unless bug.nil?
        assert_equal(silent, exc.silent?) unless silent.nil?
        assert_equal(message, exc.message) unless message.nil?
        assert_equal(klass, exc.class) unless klass.nil?
        want_function = T.must(caller_locations(1, 1)&.first&.label)
        assert(
          exc.backtrace&.detect { |l| !l.match?(/sorbet-runtime/) }&.index(want_function),
          'backtrace trimming looks wrong',
        )
      end
    end
  end
end
