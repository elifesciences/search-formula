# `search` formula

This repository contains instructions for installing and configuring the `search` project.

This repository should be structured as any Saltstack formula should, but it should also conform to the structure 
required by the [builder](https://github.com/elifesciences/builder) project.

## creating and restoring OpenSearch snapshots

Creating a snapshot of all indices in an OpenSearch database will require a 'repository' and approximately the 
same amount of disk space as the set of indices themselves.

An OpenSearch 'repository' is a formal location shared across all nodes in an OpenSearch cluster.

A snapshot is created in a repository and is available across all nodes. If there is a single node then the repository 
isn't that special, it's just a directory on the filesystem.

Creating repositories and snapshots is easy. Subsequent snapshots in the same repository are incremental and will only 
capture the changes made since the last snapshot.

### creating repositories

Before a snapshot can exist it must be created in a place OpenSearch knows about called a 'repository'. 
`fs` type repositories exist on the filesystem and OpenSearch needs to know their location at time of repository 
creation. All `fs` type repositories must specify an absolute path that is rooted in the setting `path.repo` setting in 
[`/src/opensearch/custom-opensearch.yml`](https://github.com/elifesciences/search-formula/blob/de9f8441b8d488bfe8ab75bb9a7a40162e9069c2/salt/search/config/srv-opensearch-custom-opensearch.yml#L20).

To create a repository issue this api call: `PUT /_snapshot/{repo}` with the payload:

```json
{"type": "fs", "settings": {"location": "$repo"}}
```

Replacing `$repo` with the name of a path rooted in the `path.repo` setting (multiple paths may exist).

[Reference](https://opensearch.org/docs/1.1/opensearch/snapshot-restore/#register-repository)

### creating snapshots

To create a snapshot issue this api call: `PUT /_snapshot/{repo}/{snapshot}?wait_for_completion=true`

And a snapshot will be created, blocking until it is complete.

The repository location with the snapshot information can then be zipped and distributed to another OpenSearch instance
and restored.

See [create-snapshot.sh](./salt/search/scripts/opensearch-create-snapshot.sh)

[Reference](https://opensearch.org/docs/1.1/opensearch/snapshot-restore/#take-snapshots)

### restoring snapshots

To restore a snapshot the snapshot must exist in a repository known to OpenSearch, so 
[create a repository](#creating-repositories) first.

Next, the index into which the OpenSearch snapshot is to be restored must be *closed* ([reference](https://opensearch.org/docs/1.1/opensearch/rest-api/index-apis/close-index/)).

To close *all* indices, issue the api call: `POST /_all/_close`

To restore a snapshot, issue the api call: `POST /_snapshot/{repo}/{snapshot}/_restore?wait_for_completion=true`

Like the `_snapshot` call, this will block until the restore is complete.

You can remove the URL parameter to get a non-blocking call. The state of the restore process can then be checked with:
`GET /_snapshot/{repo}/{snapshot}`

Once restored, the indices need to be opened again: `POST /_all/_open`

See [restore-snapshot.sh](./salt/search/scripts/opensearch-restore-snapshot.sh)

[Reference](https://opensearch.org/docs/1.1/opensearch/snapshot-restore/#restore-snapshots)

## Copyright & Licence

Copyright 2016-2022 eLife Sciences. [MIT licensed](LICENCE.txt)
