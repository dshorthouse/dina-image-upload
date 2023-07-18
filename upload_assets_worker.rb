#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require "config"
require "sqlite3"
require "dina"
require "time"
require "./database/database"

$stdout.sync = true

ARGV << '-h' if ARGV.empty?

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: upload_assets.rb [options]"

  opts.on("-i", "--rowid [rowid]", Integer, "Identifier to query in directories table") do |rowid|
    OPTIONS[:rowid] = rowid
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def load_config
  Config.load_and_set_settings(File.join("config", "dina.yml"))
  Dina.config = Settings.dina.to_h
  @db = Database.new(file: Settings.database)
end

def calculated_hash(path:, hash_function:)
  if hash_function == "Double SHA-1"
    `openssl dgst -binary -sha1 "#{path}" | openssl sha1`.split(" ").last
  elsif hash_function == "SHA-1"
    `openssl dgst -sha1 "#{path}"`.split(" ").last
  end
end

if OPTIONS[:rowid]
  load_config
  directory = @db.select_directory(rowid: OPTIONS[:rowid])

  if !File.directory?(directory)
    error = {
      directory: directory,
      type: 'directory missing'
    }
    @db.insert(table: "errors", hash: error)
    puts "directory missing: #{directory}"
    exit
  end

  response = {
    directory: nil,
    object: nil,
    derivative: nil,
    image_original: nil,
    image_derivative: nil
  }

  begin
    # Read the sidecar file
    sidecar = File.join(directory, "metadata.yml")
    yml = YAML.load_file(sidecar)
    original_directory = yml["managedAttributes"]["original_directory_name"]

    response[:directory] = original_directory

    # Hard-coded UUID to a Person agent for performance
    person = Dina::Person.new
    person.id = "d3681c90-80a3-43b7-8471-23ef718c3967"

    # Upload the original file
    original = Dina::File.new
    original.group = "DAO"
    original.file_path = File.join(directory, yml["original"])
    original.filename = yml["uploadWithFilename"]

    if original.save
      response[:image_original] = original.id
    else
      error = {
        directory: directory,
        type: 'original file'
      }
      @db.insert(table: "errors", hash: error)
      raise "original file did not upload: #{directory}"
    end

    # Create the metadata entry
    metadata = Dina::ObjectStore.new
    metadata.group = "DAO"
    metadata.dcType = "IMAGE"
    extension = yml["original"][-3..-1].downcase
    if extension == "cr2"
      metadata.dcFormat = "image/x-canon-cr2"
      metadata.fileExtension = ".cr2"
    elsif extension == "nef"
      metadata.dcFormat = "image/x-nikon-nef"
      metadata.fileExtension = ".nef"
    end
    metadata.fileIdentifier = original.id
    metadata.orientation = yml["orientation"]
    if original.dateTimeDigitized
      date_time = Time.find_zone("America/New_York")
                      .parse(original.dateTimeDigitized)
                      .rfc3339
                      .to_s rescue nil
      metadata.acDigitizationDate = date_time
    end
    metadata.managedAttributes = yml["managedAttributes"].compact
    metadata.ac_metadata_creator = person
    metadata.dc_creator = person

    if metadata.save
      response[:object] = metadata.id

      # Check the SHA1 hashes
      hash = calculated_hash(path: original.file_path, hash_function: metadata.acHashFunction)
      if metadata.acHashValue != hash
        metadata.destroy
        error = {
          directory: directory,
          type: 'hash mismatch',
        }
        @db.insert(table: "errors", hash: error)
        raise "hashes do not match: #{directory}"
      end
    else
      error = {
        directory: directory,
        type: 'metadata'
      }
      @db.insert(table: "errors", hash: error)
      raise "metadata did not save: #{directory}"
    end

    # Upload the derivative image
    derivative = Dina::File.new
    derivative.group = "DAO"
    derivative.file_path = File.join(directory, yml["derivative"])
    derivative.is_derivative = true

    if derivative.save
      response[:image_derivative] = derivative.id
    else
      error = {
        directory: directory,
        type: 'derivative file'
      }
      @db.insert(table: "errors", hash: error)
      raise "derivative file did not upload: #{directory}"
    end

    # Create the derivative metadata
    metadata_derivative = Dina::Derivative.new
    metadata_derivative.bucket = "dao"
    metadata_derivative.dcType = "IMAGE"
    metadata_derivative.dcFormat = "image/jpeg"
    metadata_derivative.fileExtension = ".jpg"
    metadata_derivative.derivativeType = "LARGE_IMAGE"
    metadata_derivative.fileIdentifier = derivative.id
    metadata_derivative.ac_derived_from = metadata

    if metadata_derivative.save
      response[:derivative] = metadata_derivative.id
    else
      error = {
        directory: directory,
        type: 'derivative metadata'
      }
      @db.insert(table: "errors", hash: error)
      raise "derivative metadata did not save: #{directory}"
    end

    # Write the UUIDs into the sidecar file
    if yml.key?("productionUUIDs")
      yml["productionUUIDs"]["metadata"] = response[:object]
      yml["productionUUIDs"]["original"] = response[:image_original]
      yml["productionUUIDs"]["derivative"] = response[:image_derivative]
      File.open(sidecar, 'w') { |f| f.write(yml.to_yaml) }
    end

    @db.insert(table: "logs", hash: response)
    @db.delete_directory(rowid: OPTIONS[:rowid])
    puts response.to_s
  rescue Exception => e
    error = {
      directory: directory,
      type: "exception"
    }
    @db.insert(table: "errors", hash: error)
    puts e.message + ": #{directory}"
    raise
  end

end
