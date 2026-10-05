puts "# START .pryrc ##########################################################"

# Auto-loaded things ###########################################################

begin
  require 'pry-byebug'
  ::Pry.commands.alias_command 'cc', 'continue'  # Continue
  ::Pry.commands.alias_command 'ss', 'step'      # Step-into
  ::Pry.commands.alias_command 'nn', 'next'      # Step-over
  ::Pry.commands.alias_command 'ff', 'finish'    # Step-out
  puts "Pry-byebug aliases:\n\tcontinue: cc\n\tstep: ss\n\tnext: nn\n\tfinish: ff"
rescue LoadError
  puts "Skipping pry-byebug"
end

begin
  require 'rails/console/app'
  extend ::Rails::ConsoleMethods
rescue LoadError
  puts "Skipping rails"
end

# Load-on-request things #######################################################

def n__load_url_helpers
  include ::Rails.application.routes.url_helpers
  default_url_options[:host] = "localhost:4000"
  puts 'Set default_url_options[:host] = "localhost:4000"'
end

def n__load_factory_bot
  include ::FactoryBot::Syntax::Methods
  puts "\n/!\\ Warning: Current rails env is #{Rails.env}, not test!\n\n" unless Rails.env.test?
end

# ActiveRecord helpers #########################################################

def n__ar_connection
  ::ActiveRecord::Base.connection
end

def n__ar_connection_raw
  ::ActiveRecord::Base.connection.raw_connection
end

def n__ar_exec_query(*args)
  ::ActiveRecord::Base.connection.exec_query(*args)
end

def n__ar_exec_update(*args)
  ::ActiveRecord::Base.connection.exec_update(*args)
end

def n__ar_reset_transaction
  ::ActiveRecord::Base.connection.rollback_db_transaction
  ::ActiveRecord::Base.connection.begin_db_transaction
end

def n__ar_relations(model_class)
  rel_types = %i(has_one has_many has_and_belongs_to_many belongs_to)

  result = {}
  rel_types.map do |rel_type|
    result[rel_type] = model_class.reflect_on_all_associations(rel_type).map do |r|
      desc = "#{r.name} => #{r.class_name}"
      desc += " (#{r.options})" unless r.options.empty?
      desc
    end
  end
  result
end

puts "# FINISH .pryrc #########################################################"

