# DINA Image Upload

The [DINA Consortium][1] develops an open-source web-based information management system for natural history data that consists of several connected software components. At the core of the system is support for assembling, managing and sharing data associated with natural history collections and their curation ("collection management"). Target collections include zoological, botanical, geological and paleontological collections, living collections, biodiversity inventories, observation records, and molecular data.

This basic script uploads image assets using the [dina ruby gem][9] via the AAFC biocluster from its mounted isilon.

### Disclaimer

This script is under development and contains a number of hard-coded features. It is not meant to be a full-featured asset upload utility.

### Requirements & Dependencies

- ruby >= 3.1
- bundled dependencies: [dina][9], [json_api_client][5] (\~> 1.20), [keycloak][10] (\~> 3.2.1),

### Install

```bash
$ gem install colorize dina sqlite3
```
### Configuration

Create SQLite database:

```ruby
require "sqlite3"

# Open a database
db = SQLite3::Database.new "image-upload.db"

# Create tables
rows = db.execute <<-SQL
  create table logs (
    original_directory varchar(256),
    object char(36),
    derivative char(36),
    image_original char(36),
    image_derivative char(36)
  );
SQL
rows = db.execute <<-SQL
  create table errors (
    type varchar(256),
    original_directory varchar(256)
  );
SQL
```

See configuration for the dina gem in upload_assets_worker.rb

### Execution

`./load-jobs.rb -d /my-root-directories`

### SQLite Specifics

```
$ sqlite3 image-upload.db

# Show tables
sqlite> .tables
errors logs

# Show schema
sqlite> .schema

# Select all records from tables
sqlite> SELECT * FROM errors;
sqlite> SELECT * FROM logs;

# Truncate tables
sqlite> DELETE FROM errors;
sqlite> DELETE FROM logs;

# Exit out from sqlite
ctrl-d
```

### Support

Bug reports can be filed at [https://github.com/dshorthouse/dina-image-upload/issues][3].

### Copyright
Copyright © 2023 Government of Canada

Authors: [David P. Shorthouse][4]

### License

`dina-image-upload` is released under the [MIT license][2].

[1]: https://dina-project.net/
[2]: http://www.opensource.org/licenses/MIT
[3]: https://github.com/dshorthouse/dina-image-upload/issues
[4]: https://github.com/dshorthouse
[5]: https://github.com/JsonApiClient/json_api_client
[9]: https://rubygems.org/gems/dina
[10]: https://github.com/imagov/keycloak
