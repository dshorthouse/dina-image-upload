#!/usr/bin/env ruby
# encoding: utf-8

require "colorize"
require "config"
require "sqlite3"
require "./database/database"

Config.load_and_set_settings(File.join("config", "dina.yml"))
db = Database.new(file: Settings.database)
db.create_schema

puts "Done!".green
