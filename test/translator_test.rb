require 'test_helper'

class TranslatorTest < ActiveSupport::TestCase
  include Translator::Assertions
  
  setup do
    @translator = Translator::Translator.new(from: :en, to: :fr, dir: 'test/dummy/config/locales/multilingual')
  end
  
  assert_no_missing_keys_for_available_locales

  it 'ensures export keys match import keys' do
    export = @translator.export_keys
    assert_same_array @translator.find_missing_keys,
      @translator.import_keys(export).keys
  end

  it 'ensures export keys match import keys with translation' do
    export = @translator.export_keys
    assert_same_hash @translator.prepare_translations_for_missing_keys,
      @translator.import_keys(export)
  end

  it 'finds duplicate keys' do
    yaml = <<-EOS
      nl:
        messages:
          eat: poo
        messages:
          neat: poo
          beat: mee
        beat: pea
    EOS

    error = assert_raises RuntimeError do
      assert_no_duplicate_keys yaml, raise_error: true
    end
    
    assert_equal 'Duplicates found: [{"key":"__nl__messages","line":4}]', error.message
  end

  it 'properly asserts translations without duplicates' do
    yaml = <<-EOS
      nl:
        messages1:
          eat: poo
        messages2:
          neat: poo
        peat:
        - :eat
        - :this
        beat:
        - peat
        - meat
    EOS
    
    assert_no_duplicate_keys yaml    
  end

end
