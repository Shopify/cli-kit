# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Util
      class << self
        extend T::Sig
        #
        # Converts an integer representing bytes into a human readable format
        #
        sig { params(bytes: Integer, precision: Integer, space: T::Boolean).returns(String) }
        def to_filesize(bytes, precision: 2, space: false)
          to_si_scale(bytes, 'B', precision: precision, space: space, factor: 1024)
        end

        # Converts a number to a human readable format on the SI scale
        #
        sig do
          params(number: Numeric, unit: String, factor: Integer, precision: Integer, space: T::Boolean)
            .returns(String)
        end
        def to_si_scale(number, unit = '', factor: 1000, precision: 2, space: false)
          raise ArgumentError, 'factor should only be 1000 or 1024' unless [1000, 1024].include?(factor)

          small_scale = ['m', 'µ', 'n', 'p', 'f', 'a', 'z', 'y']
          big_scale = ['k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']
          negative = number < 0
          number = number.abs.to_f

          if number == 0.0 || number.between?(1, factor)
            prefix = ''
            scale = 0
          else
            scale = Math.log(number, factor).floor
            if number < 1
              index = [-scale - 1, small_scale.length].min
              scale = -(index + 1)
              prefix = T.must(small_scale[index])
            else
              index = [scale - 1, big_scale.length].min
              scale = index + 1
              prefix = T.must(big_scale[index])
            end
          end

          divider = (factor**scale)
          fnum = (number / divider.to_f).round(precision)

          # Trim useless decimal
          fnum = fnum.to_i if (fnum.to_i.to_f * divider.to_f) == number

          fnum = -fnum if negative
          if space
            prefix = ' ' + prefix
          end

          "#{fnum}#{prefix}#{unit}"
        end

        # Dir.chdir, when invoked in block form, complains when we call chdir
        # again recursively. There's no apparent good reason for this, so we
        # simply implement our own block form of Dir.chdir here.
        sig do
          type_parameters(:T).params(dir: String, block: T.proc.returns(T.type_parameter(:T)))
            .returns(T.type_parameter(:T))
        end
        def with_dir(dir, &block)
          prev = Dir.pwd
          begin
            Dir.chdir(dir)
            yield
          ensure
            Dir.chdir(prev)
          end
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
        sig do
          type_parameters(:T).params(block_that_might_raise: T.proc.returns(T.type_parameter(:T)))
            .returns(Retrier[T.type_parameter(:T)])
        end
        def begin(&block_that_might_raise)
          Retrier.new(block_that_might_raise)
        end
      end

      class Retrier
        extend T::Sig
        extend T::Generic

        BlockReturnType = type_member

        sig { params(block_that_might_raise: T.proc.returns(BlockReturnType)).void }
        def initialize(block_that_might_raise)
          @block_that_might_raise = block_that_might_raise
        end

        sig do
          params(
            exception: T.class_of(Exception),
            retries: Integer,
            before_retry: T.nilable(T.proc.params(e: Exception).void),
          ).returns(BlockReturnType)
        end
        def retry_after(exception = StandardError, retries: 1, &before_retry)
          @block_that_might_raise.call
        rescue exception => e
          raise if (retries -= 1) < 0

          if before_retry
            if before_retry.arity == 0
              T.cast(before_retry, T.proc.void).call
            else
              T.cast(before_retry, T.proc.params(e: Exception).void).call(e)
            end
          end
          retry
        end
      end

      private_constant :Retrier
    end
  end
end
