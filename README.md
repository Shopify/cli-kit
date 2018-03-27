# cli-kit

`cli-kit` is a ruby Command-Line application framework. Its primary design goals are:

1. Modularity: The framework tries not to own your application, but rather to live on its edges.
2. Startup Time: `cli-kit` encourages heavy use of autoloading (and uses it extensively internally)
   to reduce the amount of code loaded and evaluated whilst booting your application. We are able to
   achieve a 130ms runtime in a project with 21kLoC and ~50 commands.

`cli-kit` is developed and heavily used by the Developer Infrastructure team at Shopify. We use it
to build a number of internal developer tools, along with
[cli-ui](https://github.com/shopify/cli-ui).

## Example Usage

```bash
gem install cli-kit
cli-kit new myproject
```

You can see example usage [here](https://github.com/Shopify/cli-kit-example). This app is similar to
the one that the generator generates.

## Starting a New Project
To begin creating your first `cli-kit` application, run:
```bash
cli-kit new myproject
```
Where `myproject` is the name of the application you wish to create.  Then, you will be prompted to
select how the project consumes `cli-kit` and `cli-ui`.  The available options are:
- Vendor (faster execution, more difficult to update dependencies)
- Bundler (slower execution, easier dependency management)

You're now ready to write your very first `cli-kit` application!

## How do `cli-kit` Applications Work?
The executable for your `cli-kit` app is stored in the "exe" directory.  To execute the app, simply
run:
```bash
./exe/myproject
```

### Folder Structure
* `/exe/` - Location of the executables for your application.
* `/lib/` - Location of the resources for your app (modules, classes, helpers, etc).
    * `myproject.rb` - The main file for your application.
    * `myproject/` - Stores the various commands/entry points.
        * `entry_point.rb` - Is executed when the application is launched, and handles commands.
        * `commands.rb` - Registers the various commands that your application is able to handle.
        * `commands/` - Stores Ruby files for each command (help, new, add, etc).

## Adding a New Command to your App
### Registering the Command
Let's say that you'd like your program to be able to handle a specific task, and you'd like to
_register_ a new handler for the command for that task, like `todo add` to add an item to a to-do
list.
To do this, open `/lib/myproject/commands.rb`, where `myproject` is the name of your app.  Then, add
a new line into the module, like this:
```ruby
register :Add, 'add', 'myproject/commands/add'
```

The format for this is `register` `:ActionName` `'command by user'` `'path/to/command.rb'`

### Creating the Command Action
The action for a specific command is stored in it's own Ruby file, in the `/lib/myproject/commands/`
directory.  Here is an example of the `add` command in our previous to-do app example:
```ruby
require 'myproject'

module MyProject
  module Commands
    class Add < MyProject::Command
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

Let's say that you are trying to make a to-do list app, and would like to get an argument that the
user has specified.  `args.first` will get the first argument.  For example:
```ruby
def call(args, _name)
  list = Todo::Config.get('default', 'list') || '[]'
  data = JSON.parse(list)
  data << args.first
  Todo::Config.set('default', 'list', data.to_json)
end
```

### Getting Help
Above, you'll notice that we also have a `self.help` method.  This method is what runs when the user
has incorrectly used the command, or has requested help.  For example:
```ruby
def self.help
  "Add a todo entry.\nUsage: {{command:#{Todo::TOOL_NAME} add}} {{info:data}}"
end
```

## User Interfaces
Let's make your app fancy!  Install `cli-ui`, another gem from us here at Shopify.  In your
`cli-kit` app, simply `require 'cli/ui'`, and you're good to go. For more details on how to use
`cli-ui`, visit the [`cli-ui`](https://github.com/Shopify/cli-ui) repo.

## Examples
- [A Simple To-Do App](https://github.com/Shopify/cli-kit-example)