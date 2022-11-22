require 'yaml'
require 'gengo'
require 'translator/railtie'

module Translator

  class Translator

    attr_reader :from, :to, :directory, :comments

    def initialize(options = {})
      @from = options[:from]
      @to = options[:to]
      @comments = options[:comments]
      @directory = options[:directory] || Translator.default_dir
    end

    def prepare_translations_for_missing_keys
      I18n.with_locale(from) do
        result =
          find_missing_keys.each_with_object({}) do |key, hash|
            hash[key] = I18n.t(key.sub("#{to}.", '')).to_s
          end

        wrap_interpolation_keys(result)
      end
    end

    def submit_to_gengo(dry_run: true)
      jobs = gengo_jobs

      if jobs.empty?
        puts "Nothing to translate from #{from} to #{to}"
        return
      else
        puts "Submitting: #{jobs.keys.join(', ')}"
      end

      unless dry_run
        response = gengo.postTranslationJobs jobs: jobs
        self.class.write_orders(new_orders: [{ id: response['response']['order_id'].to_i, to: to, from: from, prefix: Translator.prefix }])
      end
    end

    def fetch_order(order_id)
      gengo.getTranslationOrderJobs order_id: order_id
    end

    def fetch_from_gengo(order_id)
      order = fetch_order order_id
      jobs_count = order['response']['order']['total_jobs'].to_i

      pending_job_ids = []
      processed_job_ids = []

      %w[jobs_available jobs_pending].each do |list|
        pending_job_ids.concat order['response']['order'][list]
      end

      %w[jobs_reviewable jobs_approved jobs_revising].each do |list|
        processed_job_ids.concat order['response']['order'][list]
      end

      puts "Order ##{order_id}: #{jobs_count} jobs enqueued, #{processed_job_ids.size} processable, #{pending_job_ids.size} pending"

      @import = {}

      processed_job_ids.in_groups_of(50, false) do |job_ids|
        jobs = gengo.getTranslationJobs(ids: job_ids)['response']['jobs']

        # Duplicates are not translated
        if jobs.any? { |job| job['status'] == 'duplicate' }
          puts 'Found some duplicate jobs! These are skipped, as a translation will not be provided by Gengo.'
          jobs = jobs.reject { |job| job['status'] == 'duplicate' }
        end

        jobs.each do |job|
          next if job['body_tgt'].blank?

          @import[job['custom_data']] = unwrap_interpolation_keys(job['body_tgt'])
        end
      end

      finalize_order order_id if @import.count == jobs_count
    end

    def gengo_jobs
      position_index = 0

      prepare_translations_for_missing_keys.map do |key, content|
        next if content.blank?

        slug =
          if Rails::VERSION::MAJOR >= 6
            [Rails.application.class.module_parent_name, key].join(': ')
          else
            [Rails.application.class.parent_name, key].join(': ')
          end


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
            slug: slug
          }
        ]
      end.compact.to_h
    end

    def export_keys
      prepare_translations_for_missing_keys.map do |key, value|
        "[[[#{key}]]] #{value}"
      end.join("\n")
    end

    def import_file(filename)
      file_handler = File.open(filename)
      import_keys file_handler.read
      write_locale_file
    end

    def import_keys(import)
      import = unwrap_interpolation_keys(import)

      matches = import.scan %r{
        \[\[\[           # key start brackets
        ([^\]]+)         # key
        \]\]\]           # key end brackets
        ((.(?!\[\[\[))*) # value until brackets
      }xm

      @import =
        matches.each_with_object({}) do |match, hash|
          hash[match[0]] = match[1].to_s.lstrip
        end
    end

    def write_locale_file
      old_yaml    = yaml(path(to))
      new_yaml    = @import ? deflatten_keys(@import) : {}
      merged_yaml = old_yaml ? old_yaml.deep_merge(new_yaml) : new_yaml
      File.open(path(to), 'w') do |file|
        file.write deep_sort_hash(merged_yaml).to_yaml
      end
    end

    def find_missing_keys origin_file: nil, target_file: nil
      yaml_1 = yaml(origin_file || path(from))
      yaml_2 = yaml(target_file || path(to))
      keys_1 = yaml_1.present? ? flatten_keys(yaml_1[yaml_1.keys.first] || {}) : []
      keys_2 = yaml_2.present? ? flatten_keys(yaml_2[yaml_2.keys.first] || {}) : []
      (keys_1 - keys_2).map {|k| "#{to}.#{k}" }
    end

    class << self

      def translators
        result = []
        if params_exist? 'FROM', 'TO'
          result << instance
        else
          from = ENV['FROM'].presence || 'en'
          (available_locales - [from]).each do |locale|
            result << new(from: from, to: locale)
          end
        end

        result
      end

      def default_dir
        Translator.dir || 'config/locales/multilingual'
      end

      def available_locales dir = default_dir
        Dir.glob(Rails.root.join("#{dir}/??.yml")).map{|file| File.basename(file, '.yml') }
      end

      def translation_file
        Rails.root.join '.in_progress_translations'
      end

      %w(FROM TO FILE DIR PREFIX).each do |param|

        define_method param.downcase do
          ENV[param]
        end

      end

      def params_exist? *params
        params.all? { |param| ENV[param].present? }
      end

      def check_params *params
        all_are_present = params_exist?(*params)
        unless all_are_present
          STDERR.puts "usage example: rake translator FROM=en TO=fr DIR=\"config/locales\" PREFIX=activerecord FILE=en_to_fr.translate"
        end
        all_are_present
      end

      def instance **params
        new from: (params[:from] || from).to_sym,
          to: (params[:to] || to).to_sym
      end

      def read_orders
        orders = []
        if File.exist? translation_file
          File.open translation_file do |file_handler|
            orders = JSON.parse file_handler.read
          end
        end

        orders.reject! { |order| order[:prefix] != prefix  }
        orders.map(&:symbolize_keys)
      end

      def write_orders new_orders: [], finished_orders: []
        new_order_list = read_orders
        new_order_list.reject! { |order| finished_orders.include?(order[:id]) }
        new_order_list.concat(new_orders)

        if new_order_list.empty?
          File.unlink translation_file if File.exists? translation_file
        else
          File.open translation_file, 'w+' do |file_handler|
            file_handler.write new_order_list.to_json
          end
        end
      end
    end

  private

    def finalize_order order_id
      self.class.write_orders(finished_orders: [order_id])
      write_locale_file
    end

    def yaml file_path
      YAML.load((File.open(file_path)))
    end

    def path(locale)
      File.expand_path(File.join(directory, [Translator.prefix, locale, 'yml'].compact.join('.')))
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

    def wrap_interpolation_keys(hash)
      hash.transform_values do |value|
        value.gsub(/(%\{[^\}]+\})/m, '[[[\1]]]')
      end
    end

    def unwrap_interpolation_keys(string)
      string.gsub(/\[\[\[(%\{[^\}]+})\]\]\]/m, '\1')
    end

    def gengo
      Gengo::API.new api_version: '2',
        sandbox: false,
        public_key: Rails.application.credentials.gengo_public_key,
        private_key: Rails.application.credentials.gengo_private_key
    end

    def translation_file
      self.class.translation_file
    end

    def deep_sort_hash(object)
      if object.is_a?(Hash)
        map = Hash.new
        object.each {|k, v| map[k] = deep_sort_hash(v) }
        Hash[map.sort { |a, b| a[0].to_s <=> b[0].to_s } ]
      else
        object
      end
    end

  end

end
