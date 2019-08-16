require 'test_helper'

class TranslatorTest < ActiveSupport::TestCase
  include Translator::Assertions

  setup do
    @translator = Translator::Translator.new(from: :en, to: :fr, directory: 'test/dummy/config/locales/multilingual')
  end

  it 'ensures export keys match import keys' do
    export = @translator.export_keys

    assert_same_array @translator.find_missing_keys, @translator.import_keys(export).keys
  end

  it 'ensures export keys match import keys with translation' do
    export = @translator.export_keys
    assert_same_hash Hash[@translator.prepare_translations_for_missing_keys.map { |k, v| [k, @translator.send(:unwrap_interpolation_keys, v) ] }],
      @translator.import_keys(export)
  end

  it 'ensures export keys wrap and unwrap interpolations in triple brackets' do
    export = @translator.export_keys
    assert_includes export, 'These translations are missing in [[[%{language}]]]'
    assert_equal 'These translations are missing in %{language}', @translator.import_keys(export)['fr.missing_translations.title']
  end

  it 'finds duplicate keys' do
    yaml = <<-EOS
      nl:
        messages:
          eat: poo
          neat: poo
        messages:
          neat: poo
          beat: |
            Example 1: You know
            Example 1: This is just text
        beat: pea
    EOS

    error = assert_raises RuntimeError do
      assert_no_duplicate_keys yaml, raise_error: true
    end

    assert_equal 'Duplicates found: [{"key":"messages","occurrences":["line: 2","line: 5"]}]', error.message
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
