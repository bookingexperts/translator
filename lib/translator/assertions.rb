module Translator
  module Assertions
    extend ActiveSupport::Concern

    module ClassMethods
      def assert_no_missing_keys_for_available_locales
        I18n.available_locales.each do |from|
          I18n.available_locales.each do |to|
            it "has no missing frontoffice translations from #{from} to #{to}" do
              assert_no_missing_keys from, to
            end
          end
        end
      end
    end

    def assert_no_missing_keys from, to, origin_file: nil, target_file: nil
      translator = Translator.new(from: from, to: to)
      missing_keys = translator.find_missing_keys(origin_file: origin_file, target_file: target_file)

      if missing_keys.any?
        flunk(file: target_file || "config/locales/multilingual/#{to}.yml", missing: missing_keys)
      else
        true
      end
    end

    def assert_no_duplicate_keys file_or_content, raise_error: true
      if (duplicates = duplicate_keys(file_or_content)).any?
        raise_error ? raise("Duplicates found: #{duplicates.to_json}") : flunk(duplicates)
      else
        true
      end
    end

    def assert_no_missing_pluralizations(locale)
      missing = missing_pluralizations(locale)
      missing_message = missing.map { |key, missing_pluralizations| "- #{key}: #{missing_pluralizations.join(', ')}" }.join("\n")
      assert(missing.empty?, "Missing pluralizations for locale #{locale}:\n#{missing_message}")
    end

  private

    def missing_pluralizations(locale, scope: '')
      missing = {}

      I18n.with_locale(locale) do
        plural_keys = I18n.t('i18n.plural.keys').map(&:to_s)

        (I18n.t(scope.presence || '.').keys - [:i18n]).select(&:present?).each do |key|
          scoped_key = scope.present? ? "#{scope}.#{key}" : key
          value = I18n.t(scoped_key)
          if value.is_a?(Hash) && value.key?(:one) && value.key?(:other)
            if (missing_pluralizations = plural_keys - value.keys.map(&:to_s)).any?
              missing[scoped_key] = missing_pluralizations
            end
          elsif value.is_a?(Hash)
            missing.merge!(missing_pluralizations(locale, scope: scoped_key))
          end
        end
      end

      missing
    end

    def duplicate_keys? file_or_content
      duplicate_keys(file_or_content).any?
    end

    def duplicate_keys file_or_content
      content = file_or_content.is_a?(File) ? file_or_content.read : file_or_content
      duplicates        = []
      keys              = []
      current_indenting = 0
      parent_key        = ''
      content.split(/\n/).each_with_index do |line, num|
        spaces, key   = line.scan(/(^\s*)(.*):/).first
        next if spaces.nil? and key.nil?
        next if key.strip == '-'
        next if key.strip == '<<'
        indenting = spaces.length
        if indenting > current_indenting
          parent_key = keys.last
          current_indenting = indenting
        elsif indenting < current_indenting
          parts = parent_key.split('__')
          steps_back = ((current_indenting - indenting) / 2)
          steps_back.times do
            parts.pop
          end
          parent_key = parts.join('__')
          current_indenting = indenting
        end
        full_key = "#{parent_key}__#{key}"
        if keys.include? full_key
          duplicate = { key: full_key, line: (num + 1) }
          duplicate[:file] = file_or_content.path if file_or_content.is_a?(File)
          duplicates << duplicate
        else
          keys << full_key
        end
      end

      duplicates
    end

  end
end
