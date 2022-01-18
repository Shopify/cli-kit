# cli-kit

`cli-kit` is a ruby Command-Line application framework. Its primary design goals are:

1. Modularity: The framework tries not to own your application, but rather to live on its edges.
2. Startup Time: `cli-kit` encourages heavy use of autoloading (and uses it extensively internally)
   to reduce the amount of code loaded and evaluated whilst booting your application. We are able to
   achieve a 130ms runtime in a project with 21kLoC and ~50 commands.

`cli-kit` is developed and heavily used by the Developer Infrastructure team at Shopify. We use it
to build a number of internal developer tools, along with
[cli-ui](https://github.com/shopify/cli-ui).

## Getting Started

To begin creating your first `cli-kit` application, run:
```bash
gem install cli-kit
cli-kit new myproject
```

Where `myproject` is the name of the application you wish to create.  Then, you will be prompted to
select how the project consumes `cli-kit` and `cli-ui`.  The available options are:
- Vendor (faster execution, more difficult to update dependencies)
- Bundler (slower execution, easier dependency management)

You're now ready to write your very first `cli-kit` application!

## Upgrading to version 5

Version 5 includes breaking changes and significant new features. Notably:

* `autocall` is completely removed;
* A help system and command-line option parsing system is added.

Migrating away from `autocall` is as simple as replacing `autocall(:X) { y }` with `X = y`.

Using the new help system is not yet well-documented, but some hints can be found in the
`gen/ilb/gen/commands` directory of this repo. Existing commands in existing apps should continue to
work.

To use the new help system, commands should all define `invoke` instead of `call`. `invoke` takes
`name` as before, but the first argument is now an instance of `Opts`, defined in the command class,
which must be a subclass of `CLI::Kit::Opts`. For example:

```ruby
class MyCommand < CLI::Kit::BaseCommand
  class Opts < CLI::Kit::Opts
    def force
      flag(short: '-f', long: '--force', description: 'Force the operation')
    end
  end
  def invoke(op, _name)
    if op.force
      puts 'Forcing the operation'
    else
      puts 'Not forcing the operation'
    end
  end
end
```

This particular structure was chosen to allow the code to by fully typed using sorbet, as `invoke`
can be tagged with `sig { params(op: Opts, _name: String).void }`, and the `#force` method visibly
exists.

`-h/--help` is installed as a default flag, and running this command with `--help` is handled before
reaching `#invoke`, to print a help message (for which several other class methods on `BaseCommand`
provide text: `command_name`, `desc`, `long_desc`, `usage`, `example`, and `help_sections`). See
`gen/lib/gen/commands/new.rb` for an example.

## How do `cli-kit` Applications Work?

The executable for your `cli-kit` app is stored in the "exe" directory. To execute the app, simply
run:
```bash
./exe/myproject
```

### Folder Structure
* `/exe/` - Location of the executables for your application.
* `/lib/` - Location of the resources for your app (modules, classes, helpers, etc).
    * `myproject.rb` - This file is the starting point for where to look for all other files. It
    configures autoload for the app.
    * `myproject/` - Stores the various commands/entry points.
        * `entry_point.rb` - This is the file that is first called from the executable. It handles 
        loading and commands.
        * `commands.rb` - Registers the various commands that your application is able to handle.
        * `commands/` - Stores Ruby files for each command (help, new, add, etc).

## Adding a New Command to your App

### Registering the Command

Let's say that you'd like your program to be able to handle a specific task, and you'd like to
_register_ a new handler for the command for that task, like `myproject add` to add 2 numbers, like
in a calculator app.
To do this, open `/lib/myproject/commands.rb`. Then, add a new line into the module, like this:
```ruby
register :Add, 'add', 'myproject/commands/add'
```

The format for this is `register :<CommandClass>, '<command-at-cli>', '<path/to/command.rb>'`

### Creating the Command Action

The action for a specific command is stored in its own Ruby file, in the `/lib/myproject/commands/`
directory.  Here is an example of the `add` command in our previous to-do app example:
```ruby
require 'myproject'

module Myproject
  module Commands
    class Add < Myproject::Command
      def call(args, _name)
        # command action goes here
      end

      def self.help
        # help or instructions go here
      end
    end
  end
end

```

The `call(args, _name)` method is what actually runs when the `myproject add` command is executed.

- **Note:** The `args` parameter represents all the arguments the user has specified.

Let's say that you are trying to compute the sum of 2 numbers that the user has specified as
arguments.  For example:
```ruby
def call(args, _name)
  sum = args.map(&:to_i).inject(&:+)
  puts sum
end
```

### Getting Help

Above, you'll notice that we also have a `self.help` method.  This method is what runs when the user
has incorrectly used the command, or has requested help.  For example:
```ruby
def self.help
  "Print the sum of 2 numbers.\nUsage: {{command:#{Myproject::TOOL_NAME} add}} 5 7"
end
```

## User Interfaces

`cli-kit` also features `cli-ui`, another gem from us here at Shopify, which allows for the use of
powerful command-line user interface elements. For more details on how to use `cli-ui`, visit the 
[`cli-ui`](https://github.com/Shopify/cli-ui) repo.

## Examples

- [A Simple To-Do App](https://github.com/Shopify/cli-kit-example)
