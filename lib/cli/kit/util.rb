module CLI
  module Kit
    module Util
      class << self
        def snake_case(camel_case, seperator = "_")
          camel_case.to_s # MyCoolThing::MyAPIModule
            .gsub(/::/, '/') # MyCoolThing/MyAPIModule
            .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1#{seperator}\\2") # MyCoolThing::MyAPI_Module
            .gsub(/([a-z\d])([A-Z])/, "\\1#{seperator}\\2") # My_Cool_Thing::My_API_Module
            .downcase # my_cool_thing/my_api_module
        end

        def dash_case(camel_case)
          snake_case(camel_case, '-')
        end

        # The following methods is taken from activesupport
        #
        # https://github.com/rails/rails/blob/d66e7835bea9505f7003e5038aa19b6ea95ceea1/activesupport/lib/active_support/core_ext/string/strip.rb
        #
        # All credit for this method goes to the original authors.
        # The code is used under the MIT license.
        #
        # Strips indentation by removing the amount of leading whitespace in the least indented
        # non-empty line in the whole string
        #
        def strip_heredoc(str)
          str.gsub(/^#{str.scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
        end

        # Execute a block within the context of a variable enviroment
        #
        def with_environment(environment, value)
          return yield unless environment

          old_env = ENV[environment]
          begin
            ENV[environment] = value
            yield
          ensure
            old_env ? ENV[environment] = old_env : ENV.delete(environment)
          end
        end

        # Converts an integer representing bytes into a human readable format
        #
        def to_filesize(bytes)
          {
            'B'  => 1024,
            'KB' => 1024 * 1024,
            'MB' => 1024 * 1024 * 1024,
            'GB' => 1024 * 1024 * 1024 * 1024,
            'TB' => 1024 * 1024 * 1024 * 1024 * 1024,
          }.each_pair { |e, s| return "#{(bytes.to_f / (s / 1024)).round(2)}#{e}" if bytes < s }
        end

        # Dir.chdir, when invoked in block form, complains when we call chdir
        # again recursively. There's no apparent good reason for this, so we
        # simply implement our own block form of Dir.chdir here.
        def with_dir(dir)
          prev = Dir.pwd
          Dir.chdir(dir)
          yield
        ensure
          Dir.chdir(prev)
        end

        def with_tmp_dir
          require 'fileutils'
          dir = Dir.mktmpdir
          with_dir(dir) do
            yield(dir)
          end
        ensure
          FileUtils.remove_entry(dir)
        end

        # Standard way of checking for CI / Tests
        def testing?
          ci? || ENV['TEST']
        end

        # Set only in IntegrationTest#session; indicates that the process was
        # called by `session.execute` from an IntegrationTest subclass.
        def integration_test_session?
          ENV['INTEGRATION_TEST_SESSION']
        end

        # Standard way of checking for CI
        def ci?
          ENV['CI']
        end

        # Must call retry_after on the result in order to execute the block
        #
        # Example usage:
        #
        # CLI::Kit::Util.begin do
        #   might_raise_if_costly_prep_not_done()
        # end.retry_after(ExpectedError) do
        #   costly_prep()
        # end
        def begin(&block_that_might_raise)
          Retrier.new(block_that_might_raise)
        end
      end

      class Retrier
        def initialize(block_that_might_raise)
          @block_that_might_raise = block_that_might_raise
        end

        def retry_after(exception = StandardError, retries: 1, &before_retry)
          @block_that_might_raise.call
        rescue exception => e
          raise if (retries -= 1) < 0
          if before_retry
            if before_retry.arity == 0
              yield
            else
              yield e
            end
          end
          retry
        end
      end

      private_constant :Retrier
    end
  end
end
