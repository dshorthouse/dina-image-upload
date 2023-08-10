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

  opts.on("-d", "--directory [directory]", Array, "Comma-separated parent directories on isilon from which to import images") do |directories|
    OPTIONS[:directories] = directories
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
    OPTIONS[:directories].compact.each do |directory|
      if File.directory?(directory.strip)
        `fd --type f -a -e yml . "#{directory.strip}"`.split("\n").each do |path|
          index += 1
          csv << [index, File.dirname(path)]
          puts File.dirname(path)
        end
      end
    end
  end
  file
end

def clean_dirname(dir)
  dir.strip.tr("\u{202E}%$|:,;/\s\t\r\n\\", "-").gsub(/(^-)|(-$)/,"")
end

def queue_jobs(file:)
  workers = OPTIONS[:workers] ||= 3
  ids = []
  CSV.foreach(file) do |row|
    ids << row[0].to_i
  end
  min = ids.minmax[0]
  max = ids.minmax[1]
  filename = clean_dirname(OPTIONS[:directories].join("-"))
  log = File.join(Dir.pwd, 'logs', filemame + ".txt")
  error = File.join(Dir.pwd, 'errors', filename + "-errors.txt")
  `qsub -cwd -S /bin/bash -o /dev/null -e /dev/null -pe orte 1 -t "#{min}-#{max}" -tc "#{workers}" "#{Dir.pwd}"/qsub.sh --input "#{file}" --log "#{log}" --error "#{error}"`
end

if OPTIONS[:directories]
  puts "Clearing tmp csv...".yellow
  clear_tmp

  puts "Inserting indexed directories into tmp csv...".yellow
  csv = create_tmp

  puts "Queuing jobs on the biocluster...".yellow
  queue_jobs(file: csv)

  puts "Done!".green
end
