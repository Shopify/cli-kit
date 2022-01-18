# typed: true
module Enumerable
  sig { params(n: T.untyped, block: T.untyped).returns(T.untyped) }
  def min_by(n = nil, &block)
    return sort_by(&block).first unless n
    sort_by(&block).first(n)
  end if instance_method(:min_by).arity == 0
end
