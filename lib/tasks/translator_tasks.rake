namespace :translator do

  desc 'Export missing translations for a specific locale'
  task export_keys: :environment do
    next unless check_params 'FROM', 'TO'
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
    next unless check_params 'FROM', 'TO', 'FILE'
    file_handler = File.open file
    translator.import_keys file_handler.read
    translator.write_locale_file
  end

  desc 'submits the translations to gengo'
  task submit_to_gengo: :environment do
    next unless check_params 'FROM', 'TO'
    translator.submit_to_gengo
  end

  desc 'fetches the translations from gengo'
  task fetch_from_gengo: :environment do
    Translator::Translator.read_orders.each do |order|
      translator(order).fetch_from_gengo order[:id]
    end
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

  def translator **params
    Translator::Translator.new from: (params[:from] || from).to_sym,
      to: (params[:to] || to).to_sym
  end

end
