# typed: strict
# frozen_string_literal: true

class Exception
  # You'd think instance variables @bug and @silent would work here. They
  # don't. I'm not sure why. If you, the reader, want to take some time to
  # figure it out, go ahead and refactor to that.

  #: -> bool
  def bug?
    true
  end

  #: -> bool
  def silent?
    false
  end

  #: (?bool bug) -> void
  def bug!(bug = true)
    singleton_class.define_method(:bug?) { bug }
  end

  #: (?bool silent) -> void
  def silent!(silent = true)
    singleton_class.define_method(:silent?) { silent }
  end
end
