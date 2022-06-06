# typed: true

require 'gen'

module Gen
  module EntryPoint
    extend T::Sig

    sig { params(args: T::Array[String]).void }
    def self.call(args)
      cmd, command_name, args = Gen::Resolver.call(args)
      Gen::Executor.call(cmd, command_name, args)
    end
  end
end
