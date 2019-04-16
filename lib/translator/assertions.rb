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

  private

    def duplicate_keys? file_or_content
      duplicate_keys(file_or_content).any?
    end

    def duplicate_keys file_or_content
      yaml = file_or_content.is_a?(File) ? file_or_content.read : file_or_content
      duplicate_keys = []

      validator = ->(node) do
        if node.is_a?(Psych::Nodes::Mapping)
          duplicates = node.children.select.with_index { |_, i| i.even? }.group_by { |child| child.value }.select { |value, nodes| nodes.size > 1 }
          duplicates.each do |key, nodes|
            duplicate_key = {
              file: (file_or_content.path if file_or_content.is_a?(File)),
              key: key,
              occurrences: nodes.map { |occurrence| "line: #{occurrence.start_line + 1}" }
            }.compact

            duplicate_keys << duplicate_key
          end
        end

        node.children.to_a.each { |child| validator.call(child) }
      end

      ast = Psych.parse_stream(yaml)
      validator.call(ast)

      duplicate_keys
    end

  end
end
