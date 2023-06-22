#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require "csv"
require "find"
require "colorize"

ARGV << '-h' if ARGV.empty?

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: load_jobs.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Parent directory on isilon from which to import images") do |directory|
    OPTIONS[:directory] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def call_qsub(directories)
  file = File.join(Dir.pwd, 'indexed_paths', "#{DateTime.now.strftime('%Q')}.csv")
  CSV.open(file, "w") do |csv|
    directories.each do |directory|
      csv << directory
    end
  end
  min_max = directories.map{|a| a[0]}.minmax
  `qsub -cwd -S /bin/bash -o /dev/null -e /dev/null -pe orte 1 -t "#{min_max[0]}-#{min_max[1]}" -tc 5 "#{Dir.pwd}"/qsub_batch.sh --paths_list_file "#{file}"`
  puts "Batch sent for #{min_max}"
end

def flush_indexed_paths
  Dir.foreach(File.join(Dir.pwd, 'indexed_paths')) do |f|
    fn = File.join(File.join(Dir.pwd, 'indexed_paths'), f)
    File.delete(fn) if f != '.' && f != '..'
  end
end

if OPTIONS[:directory]
  flush_indexed_paths

  index = 0
  directories = []
  Find.find(OPTIONS[:directory]) do |path|
    next if File.basename(path) != "metadata.yml"
    dir = File.dirname(path)
    index += 1
    if index % 500 == 0
      directories << [index, dir]
      call_qsub(directories)
      directories = []
    else
      directories << [index, dir]
      next
    end
  end

  # Send the residual files
  call_qsub(directories)

  puts "Done!".green

end
