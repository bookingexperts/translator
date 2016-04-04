require 'yaml'
require 'gengo'

module Translator

  class Engine < Rails::Engine
  end

  class Translator

    attr_reader :from, :to, :directory, :comments

    def initialize(options = {})
      @from = options[:from]
      @to = options[:to]
      @comments = options[:comments]
      @directory = options[:directory] || "config/locales/multilingual"
      @orders = self.class.read_orders
    end

    def prepare_translations_for_missing_keys
      I18n.with_locale(from) do
        result = {}
        find_missing_keys.each do |key|
          result[key] = I18n.t(key.gsub("#{to}.", '')).to_s
        end
        result
      end
    end

    def submit_to_gengo
      jobs = gengo_jobs
      if jobs.empty?
        puts "Nothing to translate from #{from} to #{to}"
        return
      end
      response = gengo.postTranslationJobs jobs: jobs
      @orders << { id: response['response']['order_id'].to_i, to: to, from: from }
      write_orders
    end

    def fetch_from_gengo order_id
      order = gengo.getTranslationOrderJobs order_id: order_id
      job_ids = []
      %w(
        jobs_available jobs_pending jobs_reviewable jobs_approved jobs_revising
      ).each do |list|
        job_ids.concat order['response']['order'][list]
      end
      jobs = gengo.getTranslationJobs(ids: job_ids)['response']['jobs']
      @import = {}
      jobs.each do |job|
        next if job['body_tgt'].blank?
        @import[job['custom_data']] = job['body_tgt']
      end
      finalize_order order_id if @import.count == jobs.count
    end

    def gengo_jobs
      position_index = 0
      pairs = prepare_translations_for_missing_keys.map do |key, content|
        [
          key,
          {
            body_src: content,
            force: 0,
            comment: comments,
            lc_src: from,
            lc_tgt: to,
            tier: 'standard',
            custom_data: key,
            type: 'text',
            as_group: 1,
            position: (position_index += 1),
            slug: [Rails.application.class.parent_name, key].join(': ')
          }
        ]
      end
      Hash[pairs]
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
      old_yaml    = yaml(path(to))
      new_yaml    = deflatten_keys(@import)
      merged_yaml = old_yaml ? old_yaml.deep_merge(new_yaml) : new_yaml
      File.open(path(to), 'w') do |file|
        file.write merged_yaml.to_yaml
      end
    end

    def find_missing_keys origin_file: nil, target_file: nil
      yaml_1 = yaml(origin_file || path(from))
      yaml_2 = yaml(target_file || path(to))
      keys_1 = yaml_1.present? ? flatten_keys(yaml_1[yaml_1.keys.first]) : []
      keys_2 = yaml_2.present? ? flatten_keys(yaml_2[yaml_2.keys.first]) : []
      (keys_1 - keys_2).map {|k| "#{to}.#{k}" }
    end

    class << self

      def translation_file
        Rails.root.join '.in_progress_translations'
      end

      %w(FROM TO FILE).each do |param|

        define_method param.downcase do
          ENV[param]
        end

      end

      def check_params *params
        all_are_present = params.all? { |param| ENV[param].present? }
        unless all_are_present
          STDERR.puts "usage example: rake translator FROM=en TO=fr FILE=en_to_fr.translate"
        end
        all_are_present
      end

      def instance **params
        new from: (params[:from] || from).to_sym,
          to: (params[:to] || to).to_sym
      end

      def read_orders
        orders = []
        if File.exists? translation_file
          File.open translation_file do |file_handler|
            orders = JSON.parse file_handler.read
          end
        end
        orders.map(&:symbolize_keys)
      end

    end

  private

    def finalize_order order_id
      @orders.reject! do |order|
        order[:id] == order_id
      end
      write_orders
      write_locale_file
    end

    def yaml file_path
      YAML.load((File.open(file_path) rescue ''))
    end

    def path(locale)
      File.expand_path("#{directory}/#{locale}.yml")
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

    def gengo
      Gengo::API.new api_version: '2',
        sandbox: false,
        public_key: Rails.application.secrets.gengo_public_key,
        private_key: Rails.application.secrets.gengo_private_key
    end

    def translation_file
      self.class.translation_file
    end

    def write_orders
      if @orders.empty?
        File.unlink translation_file if File.exists? translation_file
      else
        File.open translation_file, 'w+' do |file_handler|
          file_handler.write @orders.to_json
        end
      end
    end

  end

end
