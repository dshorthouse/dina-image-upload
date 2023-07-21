class Database

  def initialize(opts = {})
    @db = SQLite3::Database.new opts[:file]
  end

  def create_schema
    @db.transaction do
      @db.execute "DROP TABLE IF EXISTS directories"
      @db.execute "DROP TABLE IF EXISTS logs"
      @db.execute "DROP TABLE IF EXISTS errors"

      @db.execute <<-SQL
        CREATE TABLE directories (
          directory varchar(256)
        );
      SQL
      @db.execute <<-SQL
        CREATE TABLE logs (
          directory varchar(256),
          object char(36),
          derivative char(36),
          image_original char(36),
          image_derivative char(36)
        );
      SQL
      @db.execute <<-SQL
        CREATE TABLE errors (
          directory varchar(256),
          type varchar(256)
        );
      SQL
    end
  end

  def insert(table:, hash:)
    cols = hash.keys.join(",")
    places = ("?"*(hash.keys.size)).split("").join(",")
    @db.execute "INSERT INTO #{table} (#{cols}) VALUES (#{places})", hash.values
  end

  def select_directory(rowid:)
    @db.get_first_value "SELECT directory FROM directories WHERE rowid = ?", rowid
  end

  def delete_directory(rowid:)
    @db.transaction do
      @db.execute "DELETE FROM directories WHERE rowid = ?", rowid
    end
  end

  def select_max_directory_rowid
    @db.get_first_value "SELECT MAX(rowid) FROM directories"
  end

  def update_directories_rowid
    @db.transaction do
      @db.execute "CREATE TABLE directories_tmp (directory varchar(256))"
      @db.execute "INSERT INTO directories_tmp SELECT directory FROM directories"
      @db.execute "DROP TABLE IF EXISTS directories"
      @db.execute "ALTER TABLE directories_tmp RENAME TO directories"
    end
  end

  def truncate_directories
    @db.transaction do
      @db.execute "DELETE FROM directories"
    end
  end

end
