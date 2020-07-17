module Translator
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__), '../tasks/translator_tasks.rake')
    end
  end
end
