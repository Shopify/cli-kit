# typed: false
module Enumerable
  extend(T::Sig)

  if instance_method(:min_by).arity == 0
    sig do
      params(
        n: Integer,
        block: T.proc.params(arg0: Elem).returns(Comparable),
      ).returns(T::Array[Elem])
    end
    def min_by(n = T.unsafe(nil), &block)
      return sort_by(&block).first unless n
      sort_by(&block).first(n)
    end
  end
end
