class Database

  def initialize(opts = {})
    @db_path = opts[:file]
  end

  def create_schema
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      db.transaction do
        db.execute "DROP TABLE IF EXISTS directories"
        db.execute "DROP TABLE IF EXISTS logs"
        db.execute "DROP TABLE IF EXISTS errors"

        db.execute <<-SQL
          CREATE TABLE directories (
            directory varchar(256)
          );
        SQL
        db.execute <<-SQL
          CREATE TABLE logs (
            directory varchar(256),
            object char(36),
            derivative char(36),
            image_original char(36),
            image_derivative char(36)
          );
        SQL
        db.execute <<-SQL
          CREATE TABLE errors (
            directory varchar(256),
            type varchar(256)
          );
        SQL
      end
    end
  end

  def insert(table:, hash:)
    cols = hash.keys.join(",")
    places = ("?"*(hash.keys.size)).split("").join(",")
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      db.execute "INSERT INTO #{table} (#{cols}) VALUES (#{places})", hash.values
    end
  end

  def select_directory(rowid:)
    directory = nil
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      directory = db.get_first_value("SELECT directory FROM directories WHERE rowid = ?", rowid).dup
    end
    directory
  end

  def delete_directory(rowid:)
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      db.transaction do
        db.execute "DELETE FROM directories WHERE rowid = ?", rowid
      end
    end
  end

  def select_max_directory_rowid
    id = nil
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      id = db.get_first_value("SELECT MAX(rowid) FROM directories").dup
    end
    id
  end

  def update_directories_rowid
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      db.transaction do
        db.execute "CREATE TABLE directories_tmp (directory varchar(256))"
        db.execute "INSERT INTO directories_tmp SELECT directory FROM directories"
        db.execute "DROP TABLE IF EXISTS directories"
        db.execute "ALTER TABLE directories_tmp RENAME TO directories"
      end
    end
  end

  def truncate_directories
    SQLite3::Database.new(@db_path) do |db|
      db.synchronous = 1
      db.busy_timeout = 200
      db.transaction do
        db.execute "DELETE FROM directories"
      end
    end
  end

end
