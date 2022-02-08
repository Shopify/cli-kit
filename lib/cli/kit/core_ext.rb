# typed: strong
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

  sig { void }
  def bug!
    singleton_class.define_method(:bug?) { true }
  end

  sig { void }
  def not_bug!
    singleton_class.define_method(:bug?) { false }
  end

  sig { void }
  def silent!
    singleton_class.define_method(:silent?) { true }
  end

  sig { void }
  def not_silent!
    singleton_class.define_method(:silent?) { false }
  end
end
