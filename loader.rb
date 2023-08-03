#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require "config"
require "find"
require "colorize"
require "time"
require "csv"

ARGV << '-h' if ARGV.empty?

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: loader.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Parent directory on isilon from which to import images") do |directory|
    OPTIONS[:directory] = directory
  end

  opts.on("-w", "--workers [workers]", Integer, "Specify the number of concurrent workers") do |workers|
    OPTIONS[:workers] = workers
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def clear_tmp
  Dir.foreach(File.join(Dir.pwd, 'tmp')) do |f|
    fn = File.join(File.join(Dir.pwd, 'tmp'), f)
    File.delete(fn) if f != '.' && f != '..'
  end
end

def create_tmp
  index = 0
  file = File.join(Dir.pwd, 'tmp', "#{DateTime.now.strftime('%Q')}.csv")
  CSV.open(file, "w") do |csv|
    Find.find(OPTIONS[:directory]) do |path|
      next if File.basename(path) != "metadata.yml"
      index += 1
      csv << [index, File.dirname(path)]
      puts File.dirname(path)
    end
  end
  file
end

def clean_dirname(dir)
  dir.strip.tr("\u{202E}%$|:;/\s\t\r\n\\", "-").gsub(/(^-)|(-$)/,"")
end

def queue_jobs(file:)
  workers = OPTIONS[:workers] ||= 3
  ids = []
  CSV.foreach(file) do |row|
    ids << row[0].to_i
  end
  min = ids.minmax[0]
  max = ids.minmax[1]
  log = File.join(Dir.pwd, 'logs', clean_dirname(OPTIONS[:directory]) + ".txt")
  error = File.join(Dir.pwd, 'errors', clean_dirname(OPTIONS[:directory]) + "-errors.txt")
  `qsub -cwd -S /bin/bash -o /dev/null -e /dev/null -pe orte 1 -t "#{min}-#{max}" -tc "#{workers}" "#{Dir.pwd}"/qsub.sh --input "#{file}" --log "#{log}" --error "#{error}"`
end

if OPTIONS[:directory]
  puts "Clearing tmp csv...".yellow
  clear_tmp

  puts "Inserting indexed directories into tmp csv...".yellow
  csv = create_tmp

  puts "Queuing jobs on the biocluster...".yellow
  queue_jobs(file: csv)

  puts "Done!".green
end
