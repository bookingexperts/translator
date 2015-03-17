namespace :translator do
  desc "Export missing translations for a specific locale"
  task :export_keys => :environment do
    from = ENV['FROM']
    to   = ENV['TO']
    if from.present? and to.present?
      translator = Translator::Translator.new(
        from: from.to_sym,
        to:   to.to_sym
      )
      missing = translator.export_keys
      if missing.length > 0
        filename = "translate_#{from}_to_#{to}.txt"
        File.open(filename, 'w') do |file|
          file.write missing
        end
        puts "Created export file: #{filename}"
      else
        puts "There are no missing translations from #{from} to #{to}"
      end
    else
      puts "Please provide locale to translate for example:"
      puts "rake translator FROM=en TO=fr"
    end
  end

  desc "Import missing translations for a specific locale"
  task :import_keys => :environment do
    if ENV['FROM'].present? and ENV['TO'].present? and ENV['FILE'].present?
      translator = Translator::Translator.new(
        from: ENV['FROM'].to_sym,
        to:   ENV['TO'].to_sym
      )
      file = File.open(ENV['FILE'])
      translator.import_keys(file.read)
      translator.write_locale_file
    else
      puts "Please provide the following arguments:"
      puts "rake translator FROM=en TO=fr FILE=en_to_fr.translate"
    end
  end
end
