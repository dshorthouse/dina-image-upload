# DINA Image Upload

The [DINA Consortium][1] develops an open-source web-based information management system for natural history data that consists of several connected software components. At the core of the system is support for assembling, managing and sharing data associated with natural history collections and their curation ("collection management"). Target collections include zoological, botanical, geological and paleontological collections, living collections, biodiversity inventories, observation records, and molecular data.

This basic script uploads image assets using the [dina ruby gem][9] via the AAFC biocluster from its mounted isilon.

## Disclaimer

This script is under development and contains a number of hard-coded features. It is not meant to be a full-featured asset upload utility.

## Requirements & Dependencies

- ruby >= 3.1
- bundled dependencies: [dina][9], [json_api_client][5] (\~> 1.20), [keycloak][10] (\~> 3.2.1),

## Install

```bash
$ git clone https://github.com/dshorthouse/dina-image-upload.git
$ conda env create -f conda/environment.yml
$ conda activate dina
$ gem install byebug colorize dina sqlite3
```
## Configuration

Create SQLite database:
```bash
$ irb
```

```ruby
require "sqlite3"

# Open a database
db = SQLite3::Database.new "image-upload.db"

# Create tables
rows = db.execute <<-SQL
  CREATE TABLE directories (
    id integer,
    directory varchar(256)
  );
SQL
rows = db.execute <<-SQL
  CREATE TABLE logs (
    directory varchar(256),
    object char(36),
    derivative char(36),
    image_original char(36),
    image_derivative char(36)
  );
SQL
rows = db.execute <<-SQL
  CREATE TABLE errors (
    directory varchar(256),
    type varchar(256)
  );
SQL
# Add an index to the directories table
db.execute("CREATE UNIQUE INDEX id_idx ON directories(id);")
```

Change the `Dina.config` hash variables in `upload_assets_worker.rb`.

## Execution

### Load jobs on the biocluster

#### Nested directory traversal
`./load-jobs.rb --directory /isilon/ottawa-rdc-htds/2019_06 --nested`

#### Non-nested directory traversal
(two-levels deep)

`./load-jobs.rb --directory /isilon/ottawa-rdc-htds/data_20211221`

The `load-jobs.rb` script:
- truncates the `directories` table in the `image-upload.db` SQLite database
- creates entries in the `directories` table for the isilon that each contain a `metadata.yml` file via the provided directory (`--directory` parameter above)
- calls `qsub` with 3 workers (`-tc 3`) and a range of indexed directories (eg `-t 1-500`), passes `qsub_batch.sh` for the nodes to execute
- `qsub_batch.sh` is invoked by a node in the biocluster that:
  - activates the dina conda environment
  - changes to the `~/dina-image-upload` directory
  - receives the integer value from the `--identifier` parameter (automatically passed via `qsub`'s $SGE_TASK_ID above)
- `qsub_batch.sh` calls `upload_assets_worker.rb` from a node in the biocluster, which receives the $SGE_TASK_ID integer to select a directory from the `directories` SQLite table
- `upload_assets_worker.rb` processes the directory on the isilon and writes to the `image-upload.db` SQLite database and also `puts` a response to `qsub_batch.sh` that writes to `upload_assets_output.csv` for additional logging.

### SQLite Helper Queries

```bash
$ sqlite3 image-upload.db

# Show tables
sqlite> .tables
errors logs directories

# Show schema
sqlite> .schema

# Select all records from tables
sqlite> SELECT * FROM errors;
sqlite> SELECT * FROM logs;
sqlite> SELECT * FROM directories;

# Truncate tables
sqlite> DELETE FROM errors;
sqlite> DELETE FROM logs;
sqlite> DELETE FROM directories;

# Exit out from sqlite
ctrl-d
```

## Support

Bug reports can be filed at [https://github.com/dshorthouse/dina-image-upload/issues][3].

## Copyright
Copyright © 2023 Government of Canada

Authors: [David P. Shorthouse][4]

## License

`dina-image-upload` is released under the [MIT license][2].

[1]: https://dina-project.net/
[2]: http://www.opensource.org/licenses/MIT
[3]: https://github.com/dshorthouse/dina-image-upload/issues
[4]: https://github.com/dshorthouse
[5]: https://github.com/JsonApiClient/json_api_client
[9]: https://rubygems.org/gems/dina
[10]: https://github.com/imagov/keycloak
