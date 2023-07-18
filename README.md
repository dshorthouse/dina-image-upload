# DINA Image Upload

The [DINA Consortium][1] develops an open-source web-based information management system for natural history data that consists of several connected software components. At the core of the system is support for assembling, managing and sharing data associated with natural history collections and their curation ("collection management"). Target collections include zoological, botanical, geological and paleontological collections, living collections, biodiversity inventories, observation records, and molecular data.

This basic pipeline uploads image assets using the [dina ruby gem][2] via the AAFC biocluster from its mounted isilon via a conda environment and stores outputs in SQLite.

## Disclaimer

These scripts are under development and contain a number of hard-coded features. This project is not meant to be a full-featured asset upload utility.

## Install

```bash
$ git clone https://github.com/dshorthouse/dina-image-upload.git
$ conda env create -f conda/environment.yml
$ conda activate dina
$ gem install byebug colorize dina sqlite3 config
```
## Configuration

```bash
$ cp config/dina.yml.sample config/dina.yml
$ cp config/token.json.sample config/token.json
```
1. Adjust content in `/config/dina.yml`
2. Create SQLite tables in a database: `./create_database.rb`

## Execution

Use a directory on the biocluster:

`./load-jobs.rb --directory /isilon/ottawa-rdc-htds/data_20211221`

Or, use entries in the directories table in the database:

`./load-jobs.rb --database`

And that's it!

You can see if jobs are loaded and starting to work by typing `$ qstat`. If there's a disaster, you can delete queued jobs via `$ qdel <JOBID>`.

### Description of Workflow

- `load-jobs.rb`:
  - by passing a `--directory` value, it first truncates the working `directories` table in the `database/image-upload.db` SQLite database
  - if you instead pass `--database`, it does not truncate but uses the existing content from the `directories` table (useful if you want more control over what gets uploaded)
  - creates entries in the `directories` table for the isilon that each contain a `metadata.yml` file
  - calls `qsub` with 3 workers (`-tc 3`) and a range of indexed directories (eg `-t 1-500`), passes `qsub_batch.sh` for the nodes to execute
- `qsub_batch.sh` is invoked by a node in the biocluster that:
  - activates the dina conda environment
  - changes to the `~/dina-image-upload` directory
  - receives the integer value from the `--rowid` parameter (automatically passed via `qsub`'s $SGE_TASK_ID above)
  - calls `upload_assets_worker.rb` and passes `--rowid $SGE_TASK_ID`
- `upload_assets_worker.rb`:
  - selects a directory from the SQLite database
  - reads the `metadata.yml` file
  - creates an object store metadata entry
  - uploads the files to the bucket
  - verifies the SHA1 post-upload for the CR2 or the NEF
  - writes to either the `logs` or `errors` table in the `image-upload.db` SQLite database
  - `puts` a response that `qsub_batch.sh` receives, which writes to `upload_assets_output.csv` for additional logging
  - deletes the entry in the `directories` table

### Best Practices

After jobs execute for a given directory, check to see if there are any entries in the `errors` or `directories` tables (see below). The latter _should_ be empty because entries are deleted when a given job completes. If not, you may wish to send these again by executing:

`./load-jobs.rb --database`

...which does not not first truncate the `directories` table unlike when using the `--directory` parameter.

### SQLite Helper Queries

```bash
$ sqlite3 database/image-upload.db

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

`dina-image-upload` is released under the [MIT license][5].

[1]: https://dina-project.net/
[2]: https://rubygems.org/gems/dina
[3]: https://github.com/dshorthouse/dina-image-upload/issues
[4]: https://github.com/dshorthouse
[5]: http://www.opensource.org/licenses/MIT
