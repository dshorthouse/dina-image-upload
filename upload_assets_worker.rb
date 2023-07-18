#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require "csv"
require "dina"
require "time"
require "sqlite3"

$stdout.sync = true

ARGV << '-h' if ARGV.empty?

DATABASE = SQLite3::Database.new File.join(Dir.pwd, "image-upload.db")

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: upload_assets.rb [options]"

  opts.on("-i", "--identifier [id]", Integer, "Identifier to query in directories table") do |id|
    OPTIONS[:id] = id.to_i
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def dina_config
  Dina.config = {
    authorization_url: 'https://dina.biodiversity.agr.gc.ca/auth',
    endpoint_url: 'https://dina.biodiversity.agr.gc.ca/api',
    realm: 'dina',
    client_id: 'dina-public',
    user: '<<username>>',
    password: '<<password>>',
    token_store_file: File.join(Dir.pwd, 'config', "token.json")
  }
end

def calculated_hash(path:, hash_function:)
  if hash_function == "Double SHA-1"
    `openssl dgst -binary -sha1 "#{path}" | openssl sha1`.split(" ").last
  elsif hash_function == "SHA-1"
    `openssl dgst -sha1 "#{path}"`.split(" ").last
  end
end

def db_insert(table:, hash:)
  cols = hash.keys.join(",")
  places = ("?"*(hash.keys.size)).split("").join(",")
  DATABASE.execute "INSERT INTO #{table} (#{cols}) VALUES (#{places})", hash.values
end

def db_select_path(id:)
  DATABASE.get_first_value "SELECT directory FROM directories WHERE id = ?", id
end

if OPTIONS[:id]
  dina_config
  directory = db_select_path(id: OPTIONS[:id])

  if !File.directory?(directory)
    error = {
      directory: directory,
      type: 'directory missing'
    }
    db_insert(table: "errors", hash: error)
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
    #Read the YML file, upload the image files in the same directory
    sidecar = File.join(directory, "metadata.yml")
    yml = YAML.load_file(sidecar)
    original_directory = yml["managedAttributes"]["original_directory_name"]

    response[:directory] = original_directory

    #metadata_creator = Dina::Person.find(yml["acMetadataCreator"]).first
    #dc_creator = Dina::Person.find(yml["dcCreator"]).first

    # Hard-coded link to a Person agent for performance
    # Same UUID for Person in dev2 as it is in production
    person = Dina::Person.new
    person.id = "d3681c90-80a3-43b7-8471-23ef718c3967"

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
      db_insert(table: "errors", hash: error)
      raise "original file did not upload: #{directory}"
    end

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
                      .parse(file.dateTimeDigitized)
                      .rfc3339
                      .to_s rescue nil
      metadata.acDigitizationDate = date_time
    end
    metadata.managedAttributes = yml["managedAttributes"].compact
    metadata.ac_metadata_creator = person
    metadata.dc_creator = person

    if metadata.save
      response[:object] = metadata.id
      hash = calculated_hash(path: original.file_path, hash_function: metadata.acHashFunction)
      if metadata.acHashValue != hash
        metadata.destroy
        error = {
          directory: directory,
          type: 'hash mismatch',
        }
        db_insert(table: "errors", hash: error)
        raise "hashes do not match: #{directory}"
      end
    else
      error = {
        directory: directory,
        type: 'metadata'
      }
      db_insert(table: "errors", hash: error)
      raise "metadata did not save: #{directory}"
    end

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
      db_insert(table: "errors", hash: error)
      raise "derivative file did not upload: #{directory}"
    end

    metadata_derivative = Dina::Derivative.new
    #metadata_derivative.group = "DAO" Cannot set the group here because this throws an error
    #hard-coded jpg derivative
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
      db_insert(table: "errors", hash: error)
      raise "derivative metadata did not save: #{directory}"
    end

    # Write the UUIDs into the sidecar file
    if yml.key?("productionUUIDs")
      yml["productionUUIDs"]["metadata"] = response[:object]
      yml["productionUUIDs"]["original"] = response[:image_original]
      yml["productionUUIDs"]["derivative"] = response[:image_derivative]
      File.open(sidecar, 'w') { |f| f.write(yml.to_yaml) }
    end

    db_insert(table: "logs", hash: response)
    puts response.to_s
  rescue Exception => e
    error = {
      directory: directory,
      type: "exception"
    }
    db_insert(table: "errors", hash: error)
    puts e.message + ": #{directory}"
    raise
  end

end
