require 'test_helper'

class TranslatorTest < ActiveSupport::TestCase
  def setup
    @translator = Translator::Translator.new(from: :en, to: :fr, dir: 'test/dummy/config/locales/multilingual')
  end

  def test_export_import_keys_is_the_same_flatten_keys
    export = @translator.export_keys
    assert_same_array @translator.find_missing_keys,
      @translator.import_keys(export).keys
  end

  def test_export_import_is_the_same_flatten_keys_with_translation
    export = @translator.export_keys
    assert_same_hash @translator.prepare_translations_for_missing_keys,
      @translator.import_keys(export)
  end
end
