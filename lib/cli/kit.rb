# typed: true

require 'cli/ui'

unless defined?(T)
  require('cli/kit/sorbet_runtime_stub')
end

require 'cli/kit/core_ext'

module CLI
  module Kit
    extend T::Sig

    autoload :Args,            'cli/kit/args'
    autoload :BaseCommand,     'cli/kit/base_command'
    autoload :CommandRegistry, 'cli/kit/command_registry'
    autoload :CommandHelp,     'cli/kit/command_help'
    autoload :Config,          'cli/kit/config'
    autoload :ErrorHandler,    'cli/kit/error_handler'
    autoload :Executor,        'cli/kit/executor'
    autoload :Ini,             'cli/kit/ini'
    autoload :Levenshtein,     'cli/kit/levenshtein'
    autoload :Logger,          'cli/kit/logger'
    autoload :Opts,            'cli/kit/opts'
    autoload :Resolver,        'cli/kit/resolver'
    autoload :Support,         'cli/kit/support'
    autoload :System,          'cli/kit/system'
    autoload :Util,            'cli/kit/util'

    EXIT_FAILURE_BUT_NOT_BUG = 30
    EXIT_BUG                 = 1
    EXIT_SUCCESS             = 0

    # Abort, Bug, AbortSilent, and BugSilent are four ways of immediately bailing
    # on command-line execution when an unrecoverable error occurs.
    #
    # Note that these don't inherit from StandardError, and so are not caught by
    # a bare `rescue => e`.
    #
    # * Abort prints its message in red and exits 1;
    # * Bug additionally submits the exception to the exception_reporter passed to
    #     `CLI::Kit::ErrorHandler.new`
    # * AbortSilent and BugSilent do the same as above, but do not print
    #     messages before exiting.
    #
    # Treat these like panic() in Go:
    #   * Don't rescue them. Use a different Exception class if you plan to recover;
    #   * Provide a useful message, since it will be presented in brief to the
    #       user, and will be useful for debugging.
    #   * Avoid using it if it does actually make sense to recover from an error.
    #
    # Additionally:
    #   * Do not subclass these.
    #   * Only use AbortSilent or BugSilent if you prefer to print a more
    #       contextualized error than Abort or Bug would present to the user.
    #   * In general, don't attach a message to AbortSilent or BugSilent.
    #   * Never raise GenericAbort directly.
    #   * Think carefully about whether Abort or Bug is more appropriate. Is this
    #       a bug in the tool? Or is it just user error, transient network
    #       failure, etc.?
    #   * One case where it's ok to rescue (cli-kit internals or tests aside):
    #       1. rescue Abort or Bug
    #       2. Print a contextualized error message
    #       3. Re-raise AbortSilent or BugSilent respectively.
    #
    # These aren't the only exceptions that can carry this 'bug' and 'silent'
    # metadata, however:
    #
    # If you raise an exception with `CLI::Kit.raise(..., bug: x, silent: y)`,
    # those last two (optional) keyword arguments will attach the metadata to
    # whatever exception you raise. This is interpreted later in the
    # ErrorHandler to decide how to print output and whether to submit the
    # exception to bugsnag.
    GenericAbort = Class.new(Exception) # rubocop:disable Lint/InheritException

    class Abort < GenericAbort # bug:false; silent: false
      extend(T::Sig)

      sig { returns(T::Boolean) }
      def bug?
        false
      end
    end

    class Bug < GenericAbort # bug:true; silent:false
    end

    class BugSilent < GenericAbort # bug:true; silent:true
      extend(T::Sig)

      sig { returns(T::Boolean) }
      def silent?
        true
      end
    end

    class AbortSilent < GenericAbort # bug:false; silent:true
      extend(T::Sig)

      sig { returns(T::Boolean) }
      def bug?
        false
      end

      sig { returns(T::Boolean) }
      def silent?
        true
      end
    end

    class << self
      extend T::Sig

      # Mirrors the API of Kernel#raise, but with the addition of a few new
      # optional keyword arguments. `bug` and `silent` attach metadata to the
      # exception being raised, which is interpreted later in the ErrorHandler to
      # decide what to print and whether to submit to bugsnag.
      #
      # `depth` is used to trim leading elements of the backtrace. If you wrap
      # this method in your own wrapper, you'll want to pass `depth: 2`, for
      # example.
      sig do
        params(
          exception: T.any(Class, String, Exception),
          string: T.untyped,
          array: T.nilable(T::Array[String]),
          cause: T.nilable(Exception),
          bug: T.nilable(T::Boolean),
          silent: T.nilable(T::Boolean),
          depth: Integer,
        ).returns(T.noreturn)
      end
      def raise(
        # default arguments
        exception = T.unsafe(nil), string = T.unsafe(nil), array = T.unsafe(nil), cause: $ERROR_INFO,
        # new arguments
        bug: nil, silent: nil, depth: 1
      )
        if array
          T.unsafe(Kernel).raise(exception, string, array, cause: cause)
        elsif string
          T.unsafe(Kernel).raise(exception, string, Kernel.caller(depth), cause: cause)
        elsif exception.is_a?(String)
          T.unsafe(Kernel).raise(RuntimeError, exception, Kernel.caller(depth), cause: cause)
        else
          T.unsafe(Kernel).raise(exception, exception.message, Kernel.caller(depth), cause: cause)
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        e.bug!(bug) unless bug.nil?
        e.silent!(silent) unless silent.nil?
        Kernel.raise(e, cause: cause)
      end
    end
  end
end
