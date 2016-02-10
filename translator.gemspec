$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "translator/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "translator"
  s.version     = Translator::VERSION
  s.authors     = ["Ruud Seydel"]
  s.email       = ["ruud@seydel.me"]
  s.homepage    = "https://github.com/bookingexperts/translator"
  s.summary     = "Utilities for keeping translations in sync"
  s.description = "This gem provides import and export (Gengo.com prove) of missing keys in translation files"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 4.0"
  s.add_development_dependency 'sqlite3'
  s.add_dependency "gengo", "~> 0.1"
end
