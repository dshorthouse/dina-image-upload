#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require "csv"
require "find"
require "colorize"
require "sqlite3"
require "./database/database"

ARGV << '-h' if ARGV.empty?

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: load_jobs.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Parent directory on isilon from which to import images") do |directory|
    OPTIONS[:directory] = directory
  end

  opts.on("-s", "--database", "Use entries in the directories table in SQLite") do
    OPTIONS[:database] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def load_config
  Config.load_and_set_settings(File.join("config", "dina.yml"))
  @db = Database.new(file: Settings.database)
end

def queue_jobs
  max = @db.select_max_directory_rowid
  if max
    `qsub -cwd -S /bin/bash -o /dev/null -e /dev/null -pe orte 1 -t "1-#{max}" -tc 3 "#{Dir.pwd}"/qsub_batch.sh"`
  else
    puts "No directories to queue".red
  end
end

if OPTIONS[:directory]
  load_config

  puts "Truncating directories table...".yellow
  @db.truncate_directories

  puts "Inserting into directories table..."
  Find.find(OPTIONS[:directory]) do |path|
    next if File.basename(path) != "metadata.yml"
    @db.insert(table: "directories", { directory: File.dirname(path) })
    puts File.dirname(path)
  end

  puts "Queuing jobs on the biocluster..."
  queue_jobs

  puts "Done!".green
elsif OPTIONS[:database]
  load_config

  puts "Adjusting rowid in directories table...".yellow
  @db.update_directories_rowid

  puts "Queuing jobs on the biocluster..."
  queue_jobs

  puts "Done!".green
end
