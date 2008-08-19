# # This file is copied to ~/spec when you run 'ruby script/generate rspec'
# # from the project root directory.
# ENV["RAILS_ENV"] = "test"
# require File.expand_path(File.dirname(__FILE__) + "/../../../../config/environment")
# require 'spec/rails'
# 
# Spec::Runner.configure do |config|
#   config.use_transactional_fixtures = true
#   config.use_instantiated_fixtures  = false
#   config.fixture_path = RAILS_ROOT + '/spec/fixtures'
# end
# 
# 
# ENV["RAILS_ENV"] ||= "test"
# require "#{File.dirname(__FILE__)}/../rails_root/config/environment.rb"
# require "#{RAILS_ROOT}/vendor/plugins/01_rspec_on_rails/lib/spec/rails"
# silence_warnings { RAILS_ENV = ENV['RAILS_ENV'] }
# ActiveRecord::Migrator.migrate("#{RAILS_ROOT}/db/migrate")
# 
# Spec::Runner.configure do |config|
#   config.use_transactional_fixtures = true
#   config.use_instantiated_fixtures  = false
#   config.fixture_path = File.dirname(__FILE__) + "/../fixtures/"
# end