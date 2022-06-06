# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      Error = Class.new(StandardError)

      autoload :Definition, 'cli/kit/args/definition'
      autoload :Parser, 'cli/kit/args/parser'
      autoload :Evaluation, 'cli/kit/args/evaluation'
      autoload :Tokenizer, 'cli/kit/args/tokenizer'
    end
  end
end
