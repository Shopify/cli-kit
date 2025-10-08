# typed: true

require 'cli/kit'
require 'open3'
require 'English'

module CLI
  module Kit
    module System
      SUDO_PROMPT = CLI::UI.fmt('{{info:(sudo)}} Password: ')
      class << self
        # Ask for sudo access with a message explaning the need for it
        # Will make subsequent commands capable of running with sudo for a period of time
        #
        # #### Parameters
        # - `msg`: A message telling the user why sudo is needed
        #
        # #### Usage
        # `ctx.sudo_reason("We need to do a thing")`
        #
        #: (String msg) -> void
        def sudo_reason(msg)
          # See if sudo has a cached password
          %x(env SUDO_ASKPASS=/usr/bin/false sudo -A true > /dev/null 2>&1)
          return if $CHILD_STATUS.success?

          CLI::UI.with_frame_color(:blue) do
            puts(CLI::UI.fmt("{{i}} #{msg}"))
          end
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        # - `**kwargs`: additional arguments to pass to Open3.capture2
        #
        # #### Returns
        # - `output`: output (STDOUT) of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out, stat = CLI::Kit::System.capture2('ls', 'a_folder')`
        #
        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], **untyped kwargs) -> [String, Process::Status]
        def capture2(cmd, *args, sudo: false, env: ENV.to_h, **kwargs)
          delegate_open3(cmd, args, kwargs, sudo: sudo, env: env, method: :capture2)
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        # - `**kwargs`: additional arguments to pass to Open3.capture2e
        #
        # #### Returns
        # - `output`: output (STDOUT merged with STDERR) of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out_and_err, stat = CLI::Kit::System.capture2e('ls', 'a_folder')`
        #
        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], **untyped kwargs) -> [String, Process::Status]
        def capture2e(cmd, *args, sudo: false, env: ENV.to_h, **kwargs)
          delegate_open3(cmd, args, kwargs, sudo: sudo, env: env, method: :capture2e)
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        # - `**kwargs`: additional arguments to pass to Open3.capture3
        #
        # #### Returns
        # - `output`: STDOUT of the command execution
        # - `error`: STDERR of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out, err, stat = CLI::Kit::System.capture3('ls', 'a_folder')`
        #
        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], **untyped kwargs) -> [String, String, Process::Status]
        def capture3(cmd, *args, sudo: false, env: ENV.to_h, **kwargs)
          delegate_open3(cmd, args, kwargs, sudo: sudo, env: env, method: :capture3)
        end

        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], **untyped kwargs) ?{ (IO stdin, IO stdout, Process::Waiter wait_thr) -> [IO, IO, Process::Waiter] } -> [IO, IO, Process::Waiter]
        def popen2(cmd, *args, sudo: false, env: ENV.to_h, **kwargs, &block)
          delegate_open3(cmd, args, kwargs, sudo: sudo, env: env, method: :popen2, &block)
        end

        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], **untyped kwargs) ?{ (IO stdin, IO stdout, Process::Waiter wait_thr) -> [IO, IO, Process::Waiter] } -> [IO, IO, Process::Waiter]
        def popen2e(cmd, *args, sudo: false, env: ENV.to_h, **kwargs, &block)
          delegate_open3(cmd, args, kwargs, sudo: sudo, env: env, method: :popen2e, &block)
        end

        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], **untyped kwargs) ?{ (IO stdin, IO stdout, IO stderr, Process::Waiter wait_thr) -> [IO, IO, IO, Process::Waiter] } -> [IO, IO, IO, Process::Waiter]
        def popen3(cmd, *args, sudo: false, env: ENV.to_h, **kwargs, &block)
          delegate_open3(cmd, args, kwargs, sudo: sudo, env: env, method: :popen3, &block)
        end

        # Execute a command in the user's environment
        # Outputs result of the command without capturing it
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        # - `**kwargs`: additional keyword arguments to pass to Process.spawn
        #
        # #### Returns
        # - `status`: The `Process:Status` result for the command execution
        #
        # #### Usage
        # `stat = CLI::Kit::System.system('ls', 'a_folder')`
        #
        #: (String cmd, *String args, ?sudo: (String | bool), ?env: Hash[String, String?], ?stdin: (IO | String | Integer | Symbol)?, **untyped kwargs) ?{ (String out, String err) -> void } -> Process::Status
        def system(cmd, *args, sudo: false, env: ENV.to_h, stdin: nil, **kwargs, &block)
          cmd, args = apply_sudo(cmd, args, sudo)

          out_r, out_w = IO.pipe
          err_r, err_w = IO.pipe
          in_stream = if stdin
            stdin
          elsif STDIN.closed?
            :close
          else
            STDIN
          end
          cmd, args = resolve_path(cmd, args, env)
          process = Process #: as untyped
          pid = process.spawn(env, cmd, *args, 0 => in_stream, :out => out_w, :err => err_w, **kwargs)
          out_w.close
          err_w.close

          handlers = if block_given?
            {
              out_r => ->(data) { yield(data.force_encoding(Encoding::UTF_8), '') },
              err_r => ->(data) { yield('', data.force_encoding(Encoding::UTF_8)) },
            }
          else
            {
              out_r => ->(data) { STDOUT.write(data) },
              err_r => ->(data) { STDOUT.write(data) },
            }
          end

          previous_trailing = Hash.new('')
          loop do
            break if Process.wait(pid, Process::WNOHANG)

            ios = [err_r, out_r].reject(&:closed?)
            next if ios.empty?

            readers, = IO.select(ios, [], [], 1)
            next if readers.nil? # If IO.select times out we iterate again so we can check if the process has exited

            readers.each do |io|
              data, trailing = split_partial_characters(io.readpartial(4096))
              handlers[io].call(previous_trailing[io] + data)
              previous_trailing[io] = trailing
            rescue IOError
              io.close
            end
          end

          $CHILD_STATUS
        end

        # Split off trailing partial UTF-8 Characters. UTF-8 Multibyte characters start with a 11xxxxxx byte that tells
        # how many following bytes are part of this character, followed by some number of 10xxxxxx bytes.  This simple
        # algorithm will split off a whole trailing multi-byte character.
        #: (String data) -> [String, String]
        def split_partial_characters(data)
          last_byte = data.getbyte(-1) #: as !nil
          return [data, ''] if (last_byte & 0b1000_0000).zero?

          # UTF-8 is up to 4 characters per rune, so we could never want to trim more than that, and we want to avoid
          # allocating an array for the whole of data with bytes
          min_bound = -[4, data.bytesize].min
          fb = data.byteslice(min_bound..-1) #: as !nil
          final_bytes = fb.bytes
          partial_character_sub_index = final_bytes.rindex { |byte| byte & 0b1100_0000 == 0b1100_0000 }

          # Bail out for non UTF-8
          return [data, ''] unless partial_character_sub_index

          start_byte = final_bytes[partial_character_sub_index]
          full_size = if start_byte & 0b1111_1000 == 0b1111_0000
            4
          elsif start_byte & 0b1111_0000 == 0b1110_0000
            3
          elsif start_byte & 0b1110_0000 == 0b110_00000
            2
          else
            nil # Not a valid UTF-8 character
          end
          return [data, ''] if full_size.nil? # Bail out for non UTF-8

          if final_bytes.size - partial_character_sub_index == full_size
            # We have a full UTF-8 character, so we can just return the data
            return [data, '']
          end

          partial_character_index = min_bound + partial_character_sub_index

          [
            data.byteslice(0...partial_character_index), #: as !nil
            data.byteslice(partial_character_index..-1), #: as !nil
          ]
        end

        #: -> Symbol
        def os
          return :mac if /darwin/.match(RUBY_PLATFORM)
          return :linux if /linux/.match(RUBY_PLATFORM)
          return :windows if /mingw/.match(RUBY_PLATFORM)

          raise "Could not determine OS from platform #{RUBY_PLATFORM}"
        end

        #: (String cmd, Hash[String, String?] env) -> String?
        def which(cmd, env)
          exts = os == :windows ? (env['PATHEXT'] || 'exe').split(';') : ['']
          (env['PATH'] || '').split(File::PATH_SEPARATOR).each do |path|
            exts.each do |ext|
              exe = File.join(path, "#{cmd}#{ext}")
              return exe if File.executable?(exe) && !File.directory?(exe)
            end
          end

          nil
        end

        private

        #: (String cmd, Array[String] args, (String | bool) sudo) -> [String, Array[String]]
        def apply_sudo(cmd, args, sudo)
          return [cmd, args] if !sudo || Process.uid.zero?

          sudo_reason(sudo) if sudo.is_a?(String)
          ['sudo', args.unshift('-E', '-S', '-p', SUDO_PROMPT, '--', cmd)]
        end

        #: (String cmd, Array[String] args, Hash[Symbol, untyped] kwargs, ?sudo: (String | bool), ?env: Hash[String, String?], ?method: Symbol) ?{ (?) -> untyped } -> untyped
        def delegate_open3(cmd, args, kwargs, sudo: raise, env: raise, method: raise, &block)
          cmd, args = apply_sudo(cmd, args, sudo)
          cmd, args = resolve_path(cmd, args, env)
          open3 = Open3 #: as untyped
          open3.send(method, env, cmd, *args, **kwargs, &block)
        rescue Errno::EINTR
          raise(Errno::EINTR, "command interrupted: #{cmd} #{args.join(" ")}")
        end

        # Ruby resolves the program to execute using its own PATH, but we want it to
        # use the provided one, so we ensure ruby chooses to spawn a shell, which will
        # parse our command and properly spawn our target using the provided environment.
        #
        # This is important because dev clobbers its own environment such that ruby
        # means /usr/bin/ruby, but we want it to select the ruby targeted by the active
        # project.
        #
        # See https://github.com/Shopify/dev/pull/625 for more details.
        #: (String cmd, Array[String] args, Hash[String, String?] env) -> [String, Array[String]]
        def resolve_path(cmd, args, env)
          # If only one argument was provided, make sure it's interpreted by a shell.
          if args.empty?
            prefix = os == :windows ? 'break && ' : 'true ; '
            return [prefix + cmd, []]
          end
          return [cmd, args] if cmd.include?('/')

          [which(cmd, env) || cmd, args]
        end
      end
    end
  end
end
