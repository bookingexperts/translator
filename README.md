[![Build Status](https://semaphoreci.com/api/v1/bookingexperts/translator/branches/master/badge.svg)](https://semaphoreci.com/bookingexperts/translator)

# Translator

Utilities for import and exporting missing translations

## Usage

### Adding it to your project

```ruby
#Gemfile
gem 'translator',
  git: 'git://github.com/bookingexperts/translator.git',
  group: [:development, :test]
```

### Submitting directly to Gengo

If you define the following secrets, you can use the gem to submit the
translations directly to Gengo and pull them back:

```yaml
development:
  gengo_public_key: foo
  gengo_private_key: bar
```

**pushing to Gengo**

```bash
rake translator:submit_to_gengo FROM=en TO=fr
```

**pulling from Gengo**

```bash
rake translator:fetch_from_gengo
```

If you want to have more control over what is being translated, you can export
the keys manually and post them yourself.

### Export missing keys

```bash
rake translator:export_keys FROM=en TO=fr
```

Will create an export text file which can uploaded to [Gengo.com](http://gengo.com/).
The keys are wrapped in a [[[key]]] block which ensures that translator won't translate the key.

### Import keys

```bash
rake translator:import_keys FROM=en TO=fr FILe=translate_nl_to_fr.txt
```

## Testing missing translations

Create a test file and include the following code

```ruby
require 'test_helper'

class TranslatorTest < MiniTest::Unit::TestCase
  I18n.available_locales.each do |from|
    I18n.available_locales.each do |to|
      define_method("test_missing_translations_from_#{from}_to_#{to}") do
        assert_empty Translator::Translator.new(from: from, to: to).find_missing_keys
      end
    end
  end
end
```

or you can test specific files like this:

```ruby
translator = Translator::Translator.new(from: origin_locale, to: target_locale)
assert_empty translator.find_missing_keys(origin_file: origin_file, target_file: target_file)
```
