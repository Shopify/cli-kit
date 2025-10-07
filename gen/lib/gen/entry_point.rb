# typed: true

require 'gen'

module Gen
  module EntryPoint
    class << self
      #: (Array[String] args) -> void
      def call(args)
        cmd, command_name, args = Gen::Resolver.call(args)
        Gen::Executor.call(cmd, command_name, args)
      end
    end
  end
end
