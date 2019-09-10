# typed: true
require('cli/kit')

module CLI
  module Kit
    module Autocall
      extend(T::Sig)

      sig { params(const: Symbol, block: T.proc.returns(T.untyped)).void }
      def autocall(const, &block)
        @autocalls ||= {}
        @autocalls[const] = block
      end

      sig { params(const: Symbol).returns(T.untyped) }
      def const_missing(const)
        block = begin
          @autocalls.fetch(const)
        rescue KeyError
          return super
        end
        # const_set(...), but working around Sorbet.
        Module.method(:const_set).unbind.bind(self).call(const, block.call)
      end
    end
  end
end
