class Database

  def initialize(opts = {})
    @db = SQLite3::Database.new opts[:file]
  end

  def create_schema
    @db.execute "DROP TABLE directories"
    @db.execute "DROP TABLE logs"
    @db.execute "DROP TABLE errors"

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

  def insert(table:, hash:)
    cols = hash.keys.join(",")
    places = ("?"*(hash.keys.size)).split("").join(",")
    @db.execute "INSERT INTO #{table} (#{cols}) VALUES (#{places})", hash.values
  end

  def select_directory_by_rowid(rowid:)
    @db.get_first_value "SELECT directory FROM directories WHERE rowid = ?", rowid
  end

  def delete_directory(rowid:)
    @db.execute "DELETE FROM directory WHERE rowid = ?", rowid
  end

  def select_max_directory_rowid
    @db.get_first_value "SELECT MAX(rowid) FROM directories"
  end

  def update_directories_rowid
    @db.execute "CREATE TABLE directories_tmp (directory varchar(256))"
    @db.execute "INSERT INTO directories_tmp SELECT directory FROM directories"
    @db.execute "DROP TABLE directories"
    @db.execute "ALTER TABLE directories_tmp RENAME TO directories"
  end

  def truncate_directories
    @db.execute "DELETE FROM directories"
  end

end
