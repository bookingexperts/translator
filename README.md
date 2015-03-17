# Translator

Utilities for import and exporting missing translations

## Usage

### Export missing keys

```
rake translator:export_keys FROM=en TO=fr
```

Will create an export text file which can uploaded to [Gengo.com](http://gengo.com/).
The keys are wrapped in a [[[key]]] block which ensures that translator won't translate the key.

### Import keys

```
rake translator:import_keys FROM=en TO=fr FILe=translate_nl_to_fr.txt
```

## Testing missing translations

Create a test file and include the following code

```
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
