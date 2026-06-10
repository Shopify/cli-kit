# typed: strict
# frozen_string_literal: true

class Exception
  # You'd think instance variables @bug and @silent would work here. They
  # don't. I'm not sure why. If you, the reader, want to take some time to
  # figure it out, go ahead and refactor to that.

  # Fault represents who is responsible for an error. It is used to attribute
  # exceptions to the right owner for observability and triage.
  #
  # @abstract
  # @sealed
  class Fault
    # @abstract
    #: -> String
    def to_s = raise NotImplementedError, 'abstract method called'

    # A bug in the tool itself (dev, tec, cli-kit, etc.).
    class System < Fault
      # @override
      #: -> String
      def to_s = 'system'
    end
    SYSTEM = System.new.freeze #: System

    # The default fault for exceptions that have not been explicitly attributed.
    # Nothing should reference this constant directly — it exists only as the
    # default return value of Exception#fault. Use rubocop to enforce this.
    #
    # Inherits from System so that `fault.is_a?(System)` and checks like
    # `bug?` (which uses `Fault::System ===`) treat unattributed errors as
    # system errors by default.
    class ImplicitlySystem < System
      # @override
      #: -> String
      def to_s = 'implicitly_system'
    end
    IMPLICITLY_SYSTEM = ImplicitlySystem.new.freeze #: ImplicitlySystem

    # A problem with the project's configuration (dev.yml, zone.nix, etc.).
    class Project < Fault
      # @override
      #: -> String
      def to_s = 'project'
    end
    PROJECT = Project.new.freeze #: Project

    # User error: incorrect CLI usage, expired tokens, bad arguments, etc.
    class User < Fault
      # @override
      #: -> String
      def to_s = 'user'
    end
    USER = User.new.freeze #: User

    # Not a real failure — e.g. user cancellation, interrupt, or conditions
    # wildly out of anyone's control (no disk space). Doesn't require fixing
    # or tracking.
    class Terroir < Fault
      # @override
      #: -> String
      def to_s = 'terroir'
    end
    TERROIR = Terroir.new.freeze #: Terroir
  end

  #: -> Fault
  def fault = Fault::IMPLICITLY_SYSTEM

  #: (Fault fault) -> void
  def fault!(fault)
    singleton_class.define_method(:fault) { fault }
  end

  #: (Fault fault) -> self
  def with_fault(fault)
    fault!(fault)
    self
  end

  #: -> bool
  def bug? = (Fault::System === fault)

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

# -- Custom fault defaults for Ruby stdlib exceptions --------------------------
#
# Normally, fault attribution belongs at the raise site (via `fault:` kwarg).
# These classes are different: Ruby itself raises them (e.g. the kernel sends
# SIGINT, the OS returns ENOSPC), so there is no raise site we control. We
# override the default fault at the class level instead.
#
# All of these are environmental conditions ("terroir") — nobody's fault,
# nothing to fix, shouldn't be reported as bugs.

class Interrupt # Ctrl-C / SIGINT
  #: -> Exception::Fault
  def fault = Exception::Fault::TERROIR
end

class SignalException # SIGTERM, SIGHUP, etc.
  #: -> Exception::Fault
  def fault = Exception::Fault::TERROIR
end

module Errno
  class ENOSPC # disk full
    #: -> Exception::Fault
    def fault = Exception::Fault::TERROIR
  end
end

module Errno
  class EPIPE # broken pipe
    #: -> Exception::Fault
    def fault = Exception::Fault::TERROIR
  end
end

module Errno
  class EIO # I/O error (e.g. terminal disconnected)
    #: -> Exception::Fault
    def fault = Exception::Fault::TERROIR
  end
end
