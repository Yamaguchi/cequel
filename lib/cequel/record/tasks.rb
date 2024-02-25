# -*- encoding : utf-8 -*-
task :environment do
end

namespace :cequel do
  namespace :keyspace do
    desc 'Initialize Cassandra keyspace'
    task :create => :environment do
      create!
    end

    desc 'Initialize Cassandra keyspace if not exist'
    task :create_if_not_exist => :environment do
      if Cequel::Record.connection.schema.exists?
        puts "Keyspace #{Cequel::Record.connection.name} already exists. Nothing to do."
        next
      end
      create!
    end

    desc 'Drop Cassandra keyspace'
    task :drop => :environment do
      drop!
    end

    desc 'Drop Cassandra keyspace if exist'
    task :drop_if_exist => :environment do
      unless Cequel::Record.connection.schema.exists?
        puts "Keyspace #{Cequel::Record.connection.name} doesn't exist. Nothing to do."
        next
      end
      drop!
    end
  end

  desc "Synchronize all models defined in `app/models' with Cassandra " \
       "database schema"
  task :migrate => :environment do
    migrate
  end

  desc "Create keyspace and tables for all defined models"
  task :init => %w(keyspace:create migrate)


  desc 'Drop keyspace if exists, then create and migrate'
  task :reset => :environment do
    if Cequel::Record.connection.schema.exists?
      drop!
    end
    create!
    migrate
  end

  def create!
    Cequel::Record.connection.schema.create!
    puts "Created keyspace #{Cequel::Record.connection.name}"
  end


  def drop!
    Cequel::Record.connection.schema.drop!
    puts "Dropped keyspace #{Cequel::Record.connection.name}"
  end

  def migrate
    migration_table_names = Set[]
    project_root = defined?(Rails) ? Rails.root : Dir.pwd
    models_dir_path = "#{File.expand_path('app/models', project_root)}/"
    model_files = Dir.glob(File.join(models_dir_path, '**', '*.rb'))
    model_files.sort.each do |file|
      model_file_name = file.sub(/^#{Regexp.escape(models_dir_path)}/, "")
      dirname = File.dirname(model_file_name)
      require_dependency(file)

      class_name = model_file_name.sub(/\.rb$/, "").classify
      # rubocop:disable HandleExceptions
      begin
        clazz = class_name.constantize
      rescue LoadError, NameError, RuntimeError
      else
        if clazz.is_a?(Class)
          if clazz.ancestors.include?(Cequel::Record) &&
              !migration_table_names.include?(clazz.table_name.to_sym)
            clazz.synchronize_schema
            migration_table_names << clazz.table_name.to_sym
            puts "Synchronized schema for #{class_name}"
          end
        end
      end
      # rubocop:enable HandleExceptions
    end
  end
end
