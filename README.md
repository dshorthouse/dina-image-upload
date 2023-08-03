# DINA Image Upload

The [DINA Consortium][1] develops an open-source web-based information management system for natural history data that consists of several connected software components. At the core of the system is support for assembling, managing and sharing data associated with natural history collections and their curation ("collection management"). Target collections include zoological, botanical, geological and paleontological collections, living collections, biodiversity inventories, observation records, and molecular data.

This basic pipeline uploads image assets using the [dina ruby gem][2] via the AAFC biocluster from its mounted isilon via a conda environment.

## Disclaimer

These scripts are under development and contain a number of hard-coded features. This project is not meant to be a full-featured asset upload utility.

## Install

```bash
$ git clone https://github.com/dshorthouse/dina-image-upload.git
$ conda env create -f conda/environment.yml
$ conda activate dina
$ gem install byebug colorize dina config
```
## Configuration

```bash
$ cp config/dina.yml.sample config/dina.yml
$ cp config/token.json.sample config/token.json
```
1. Adjust content in `/config/dina.yml`

## Execution

`conda activate dina`

Use a directory on the biocluster:

`./loader.rb --directory /isilon/ottawa-rdc-htds/data_20211221`

You can specify the number of concurrent workers by additionally passing `--workers INT` where INT is an integer.

And that's it!

You can see if jobs are loaded and starting to work by typing `$ qstat`. If there's a disaster, you can delete queued jobs via `$ qdel <JOBID>`.

### Description of Workflow

- `loader.rb`:
  - clears the contents of `tmp/`
  - `--directory [DIR]`: does a nested traversal of DIR
  - writes a two-column csv file in `tmp/` for instances containing a metadata.yml file: index,directory
  - `--workers [INT]`: specifies the number of concurrent workers (3 is generally functional, more may result in pooled requests in the DINA application)
  - calls `qsub` and passes `qsub.sh` for the nodes to execute
- `qsub.sh` is invoked by a node in the biocluster that:
  - activates the dina conda environment
  - changes to the `~/dina-image-upload` directory
  - reads the $input csv file passed to it from `tmp/` and obtains a directory where index == $SGE_TASK_ID to call `worker.rb`
- `worker.rb`:
  - receives a single directory
  - reads the `metadata.yml` file
  - creates an object store metadata entry
  - uploads the files to the bucket
  - verifies the SHA1 post-upload for the CR2 or the NEF
  - `puts` a response that `qsub.sh` receives, which writes to a log or error file in `logs/`

## Log Files

Given a --directory like `/isilon/ottawa-rdc-htds/2021_01/data_20210113` passed to `./loader.rb`, the log file(s) written in `logs/` will `isilon-ottawa-rdc-htds-2021_01-data_20210113.csv` and `isilon-ottawa-rdc-htds-2021_01-data_20210113-errors.csv` (if there are any).

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
