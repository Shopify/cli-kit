require 'todo'

module Todo
  ErrorHandler = CLI::Kit::ErrorHandler.new(
    log_file: Todo::LOG_FILE,
    # must support #report(<exception>, <string : logs>).
    # Useful for bugsnag, etc. -- exception tracking systems.
    exception_reporter: CLI::Kit::ErrorHandler::NullExceptionReporter
  )
end
