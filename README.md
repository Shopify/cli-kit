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

You can see example usage [here](https://github.com/Shopify/cli-kit-example). We may one day build
an application generator, as this framework paradigm requires a small amount of boilerplate. For
now, the best way to get going is to use this example application as a starting point.
