# typed: strict
# frozen_string_literal: true

class Exception
  extend(T::Sig)

  # You'd think instance variables @bug and @silent would work here. They
  # don't. I'm not sure why. If you, the reader, want to take some time to
  # figure it out, go ahead and refactor to that.

  sig { returns(T::Boolean) }
  def bug?
    true
  end

  sig { returns(T::Boolean) }
  def silent?
    false
  end

  sig { params(bug: T::Boolean).void }
  def bug!(bug = true)
    singleton_class.define_method(:bug?) { bug }
  end

  sig { params(silent: T::Boolean).void }
  def silent!(silent = true)
    singleton_class.define_method(:silent?) { silent }
  end
end
