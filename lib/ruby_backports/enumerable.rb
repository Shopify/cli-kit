module Enumerable
  def min_by(n=1, &block)
    sort_by(&block).first(n)
  end if instance_method(:min_by).arity == 0
end
