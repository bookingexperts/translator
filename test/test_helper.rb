# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'translator/assertions'

Rails.backtrace_cleaner.remove_silencers!

I18n.load_path += Dir["#{File.dirname(__FILE__)}/dummy/config/locales/multilingual/*.yml"]

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Load fixtures from the engine
if ActiveSupport::TestCase.method_defined?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
end


module Minitest::Assertions
  # Assert two enumerables have the same elements, irrespective of order
  def assert_same_array enum1, enum2, *args
    msg = message(msg) {
      note = ''
      if (missing = (enum1 - enum2)).length > 0
        note << "Expected #{missing} to be in second array"
      end
      if (missing = (enum2 - enum1)).length > 0
        note << "Expected #{missing} to be in first array"
      end
      note
    }
    assert enum1 == enum2, msg
  end

  def assert_same_hash hash1, hash2
    msg = message(msg) {
      note = []
      if (missing = (hash1.keys - hash2.keys)).length > 0
        note << "Expected #{missing} to be in second hash"
      end
      if (missing = (hash2.keys - hash1.keys)).length > 0
        note << "Expected #{missing} to be in first hash"
      end
      hash1.each do |k,v|
        if v.class != hash2[k].class
          note << "Expected #{k} to be the same type in both hashes | #{v.class} - #{hash2[k].class}"
        elsif v != hash2[k]
          note << "Expected #{k} to be the same in both hashes | '#{v}' - '#{hash2[k]}'"
        end
      end
      note.join("\n")
    }
    assert hash1 == hash2, msg
  end
end
