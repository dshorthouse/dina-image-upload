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

  opts.on("-n", "--nested", "Do nested traversal of supplied directory") do
    OPTIONS[:nested] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def db_insert(table:, hash:)
  db = SQLite3::Database.new File.join(Dir.pwd, "image-upload.db")
  cols = hash.keys.join(",")
  places = ("?"*(hash.keys.size)).split("").join(",")
  db.execute "insert into #{table} (#{cols}) values (#{places})", hash.values
end

def call_qsub(directories)
  directories.each do |directory|
    db_insert(table: "directories", hash: { id: directory[0], directory: directory[1] })
  end

  min_max = directories.map{|a| a[0]}.minmax
  `qsub -cwd -S /bin/bash -o /dev/null -e /dev/null -pe orte 1 -t "#{min_max[0]}-#{min_max[1]}" -tc 3 "#{Dir.pwd}"/qsub_batch.sh"`
  puts "Batch sent for #{min_max}"
end

def db_truncate_directories
  db = SQLite3::Database.new File.join(Dir.pwd, "image-upload.db")
  db.execute "delete from directories"
end

if OPTIONS[:directory]
  db_truncate_directories
  index = 0
  directories = []
  if OPTIONS[:nested]
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
    # Send the residual directories
    call_qsub(directories)
  else
    Dir.glob(File.join(OPTIONS[:directory], "**", "metadata.yml")).each do |path|
      next if File.basename(path) != "metadata.yml"
      dir = File.dirname(path)
      index += 1
      directories << [index, dir]
    end
    call_qsub(directories)
  end

  puts "Done!".green

end
