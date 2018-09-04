namespace :translator do

  desc 'Export missing translations for a specific locale'
  task export_keys: :environment do
    Translator::Translator.translators.each do |translator|
      missing = translator.export_keys
      if missing.length > 0
        filename = "translate_#{translator.from}_to_#{translator.to}.txt"
        filename = "#{Translator::Translator.prefix}_#{filename}" if Translator::Translator.prefix
        File.open(filename, 'w') do |file_handler|
          file_handler.write missing
        end
        puts "Created export file: #{filename}"
      else
        puts "There are no missing translations from #{translator.from} to #{translator.to}"
      end
    end
  end

  desc 'Import missing translations for a specific locale'
  task import_keys: :environment do
    if filename = Translator::Translator.file
      Translator::Translator.check_params 'FROM', 'TO', 'FILE'
      if File.exist?(filename)
        translator = Translator::Translator.instance
        translator.import_file(filename)
      end
    else
      Translator::Translator.translators.each do |translator|
        possible_filename = "translate_#{translator.from}_to_#{translator.to}.txt"
        possible_filename = "#{Translator::Translator.prefix}_#{possible_filename}" if Translator::Translator.prefix
        translator.import_file(possible_filename) if File.exist?(possible_filename)
      end
    end
  end

  desc 'submits the translations to gengo'
  task submit_to_gengo: :environment do
    dry_run = ENV['EXECUTE'] != '1'

    Translator::Translator.translators.each do |translator|
      translator.submit_to_gengo(dry_run: dry_run)
    end

    puts ''
    puts "This is a dry-run, no Gengo jobs have been submitted! Specify EXECUTE=1 to force submission." if dry_run
  end

  desc 'fetches the translations from gengo'
  task fetch_from_gengo: :environment do
    Translator::Translator.read_orders.each do |order|
      Translator::Translator.instance(order).fetch_from_gengo order[:id]
    end
  end

  desc 'writes the locale file as is'
  task write_locale_file: :environment do
    Translator::Translator.translators.each do |translator|
      translator.write_locale_file
    end
  end

  desc 'fetches the current status of pending orders from gengo'
  task status: :environment do
    require 'pp'

    Translator::Translator.read_orders.each do |order|
      puts '===================================================='
      puts ''
      puts "Order #{order[:id]} (#{order[:from]}-#{order[:to]}):"
      puts ''
      pp Translator::Translator.instance(order).fetch_order(order[:id])
      puts ''
      puts '===================================================='
      puts ''
    end
  end
end
