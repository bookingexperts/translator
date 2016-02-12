namespace :translator do

  desc 'Export missing translations for a specific locale'
  task export_keys: :environment do
    next unless Translator::Translator.check_params 'FROM', 'TO'
    from = Translator::Translator.from
    to = Translator::Translator.to
    translator = Translator::Translator.instance
    missing = translator.export_keys
    if missing.length > 0
      filename = "translate_#{from}_to_#{to}.txt"
      File.open(filename, 'w') do |file_handler|
        file_handler.write missing
      end
      puts "Created export file: #{filename}"
    else
      puts "There are no missing translations from #{from} to #{to}"
    end
  end

  desc 'Import missing translations for a specific locale'
  task import_keys: :environment do
    next unless Translator::Translator.check_params 'FROM', 'TO', 'FILE'
    file_handler = File.open Translator::Translator.file
    translator = Translator::Translator.instance
    translator.import_keys file_handler.read
    translator.write_locale_file
  end

  desc 'submits the translations to gengo'
  task submit_to_gengo: :environment do
    next unless Translator::Translator.check_params 'FROM', 'TO'
    Translator::Translator.instance.submit_to_gengo
  end

  desc 'fetches the translations from gengo'
  task fetch_from_gengo: :environment do
    Translator::Translator.read_orders.each do |order|
      Translator::Translator.instance(order).fetch_from_gengo order[:id]
    end
  end

end
