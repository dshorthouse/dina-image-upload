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
$ gem install dina
```
### Configuration

See configuration for the dina gem in upload_assets_worker.rb

### Execution

`./load-jobs.rb -d /my-root-directories`

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
[5]: https://github.com/JsonApiClient/json_api_client
[9]: https://rubygems.org/gems/dina
[10]: https://github.com/imagov/keycloak
