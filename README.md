# `search` formula

This repository contains instructions for installing and configuring the `search` project.

This repository should be structured as any Saltstack formula should, but it should also conform to the structure 
required by the [builder](https://github.com/elifesciences/builder) project.

## creating and restoring Elasticsearch snapshots

Creating a snapshot of all indices in an ElasticSearch (ES) database will require a 'repository' and approximately the 
same amount of disk space as the set of indices themselves.

An ES 'repository' is a formal location shared across all nodes in an ES cluster.

A snapshot is created in a repository and is available across all nodes. If there is a single node then the repository 
isn't that special, it's just a directory on the filesystem.

Creating repositories and snapshots is easy. Subsequent snapshots in the same repository are incremental and will only 
capture the changes made since the last snapshot.

### creating repositories

Before a snapshot can exist it must be created in a place ES knows about called a 'repository'. `fs` type repositories 
exist on the filesystem and ES needs to know their location as well with the setting `path.repo` in 
`/etc/elasticsearch/elasticsearch.yml`.

To create a repository issue this api call: `PUT /_snapshot/{repo}` with the payload:

```json
{"type": "fs", "settings": {"location": "$repo"}}
```

Where `$repo` is the name of a path rooted in the `path.repo` setting (multiple paths may exist).

[Reference](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/modules-snapshots.html#_repositories)

### creating snapshots

To create a snapshot issue this api call: `PUT /_snapshot/{repo}/{snapshot}?wait_for_completion=true`

And a snapshot will be created and the command will block until it is complete.

The repository location with the snapshot information can then be zipped up and distributed to a new, empty, ES instance
for restore.

See [create-snapshot.sh](./salt/search/scripts/create-snapshot.sh)

[Reference](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/modules-snapshots.html#_snapshot)

### restoring snapshots

To restore a snapshot the snapshot must exist in a repository known to ES, so 
[create a repository](#creating-repositories) first.

Next, the index into which the ES snapshot is to be restored must be *closed* ([reference](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/indices-open-close.html)).

To close *all* indices, issue the api call: `POST /_all/_close`

To restore a snapshot, issue the api call: `POST /_snapshot/{repo}/{snapshot}/_restore?wait_for_completion=true`

Like the `_snapshot` call, this will block until the restore is complete.

You can remove the URL parameter to get a non-blocking call. The state of the restore process can then be checked with:
`GET /_snapshot/{repo}/{snapshot}`

Once restored, the indices need to be opened again: `POST /_all/_open`

See [restore-snapshot.sh](./salt/search/scripts/restore-snapshot.sh)

[Reference](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/modules-snapshots.html#_restore)

## Copyright & Licence

Copyright 2016-2019 eLife Sciences. [MIT licensed](LICENCE.txt)
