# typed: true
require 'gen'

module Gen
  module EntryPoint
    sig { params(args: T.untyped).returns(T.untyped) }
    def self.call(args)
      cmd, command_name, args = Gen::Resolver.call(args)
      Gen::Executor.call(cmd, command_name, args)
    end
  end
end
