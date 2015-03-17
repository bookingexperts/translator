require 'yaml'

module Translator
  class Engine < Rails::Engine
  end

  class Translator
    def initialize(options = {})
      @from = options[:from]
      @to   = options[:to]
      @dir  = options[:dir] || "config/locales/multilingual"
    end

    def prepare_translations_for_missing_keys
      I18n.with_locale(@from) do
        result = {}
        find_missing_keys.each do |key|
          result[key] = I18n.t(key.gsub("#{@to}.", '')).to_s
        end
        result
      end
    end

    def export_keys
      prepare_translations_for_missing_keys.map do |key, value|
        "[[[#{key}]]] #{value}"
      end.join("\n")
    end

    def import_keys(import)
      matches = import.scan %r{
        \[\[\[           # key start brackets
        ([^\]]+)         # key
        \]\]\]           # key end brackets
        ((.(?!\[\[\[))*) # value until brackets
      }xm
      @import = {}
      matches.each do |match|
        @import[match[0]] = match[1].to_s.lstrip
      end
      @import
    end

    def write_locale_file
      old_yaml    = yaml(@to)
      new_yaml    = deflatten_keys(@import)
      merged_yaml = old_yaml ? old_yaml.deep_merge(new_yaml) : new_yaml
      File.open(path(@to), 'w') do |file|
        file.write merged_yaml.to_yaml
      end
    end

    def find_missing_keys
      yaml_1 = yaml(@from)
      yaml_2 = yaml(@to)
      keys_1 = yaml_1.present? ? flatten_keys(yaml_1[yaml_1.keys.first]) : []
      keys_2 = yaml_2.present? ? flatten_keys(yaml_2[yaml_2.keys.first]) : []
      (keys_1 - keys_2).map {|k| "#{@to}.#{k}" }
    end

  private

    def yaml(locale)
      YAML.load((File.open(path(locale)) rescue ''))
    end

    def path(locale)
      File.expand_path("#{@dir}/#{locale}.yml")
    end

    def deflatten_keys(hash)
      new_hash = {}
      hash.each do |k,v|
        new_hash.deep_merge!(
          k.split('.').reverse.inject(v) {|a,n| { n => a } }
        )
      end
      new_hash
    end

    def flatten_keys(hash, prefix="")
      keys = []
      hash.keys.each do |key|
        if hash[key].is_a? Hash
          current_prefix = prefix + "#{key}."
          keys << flatten_keys(hash[key], current_prefix)
        else
          keys << "#{prefix}#{key}"
        end
      end
      prefix == "" ? keys.flatten : keys
    end
  end
end
