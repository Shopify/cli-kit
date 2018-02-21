# cli-kit-example

This a simple demo app that shows off how to use [`cli-kit`](https://github.com/shopify/cli-kit) to
construct a simple CLI app.

Suggested reading order:

1. `exe/todo`
1. `lib/todo.rb`
1. everything else under `lib/`

You'll notice that we make heavy use of `autoload`, dependency code is vendored, and we invoke ruby
with `--disable-gems`. These are primary design feature of `cli-kit`, allowing very quick startup,
which is valuable for CLI tools.

## Two Modes

`cli-kit-example` has two options depending on how you'd like the cli-kit and cli-ui dependencies
managed: `vendor` mode and `gems` mode.

To use `vendor` mode, remove `Gemfile` and `exe/todo-gems`.

To use `gems` mode, remove `bin/update-deps`, `vendor`, and `exe/todo-gems`.

`vendor` mode boots a little faster: Bundler and in particular Rubygems have a surprisingly large
boot-time penalty, and in some situations, having all required code vendored can simplify
distribution.
