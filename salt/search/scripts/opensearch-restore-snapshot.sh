#!/bin/bash
# creates a repository in Opensearch to restore a snapshot.
# decompresses given path to snapshot file.
# closes all open indices.
# restores snapshot.
# opens all closed indices.
#
# once restored OpenSearch must be switched to use the new index.
# from the search app: ./bin/console index:

set -eu

snapshot="$1" # name of the snapshot, 'backup'
snapshot_path="$(realpath $2)" # '/tmp/backup.tar.gz'

function errcho { 
    echo "$@" 1>&2; 
}

if [ ! -f "$snapshot_path" ]; then
    errcho "file not found: $snapshot_path"
    exit 1
fi

repo="snapshots"

repo_path="/usr/share/opensearch/data/$repo"
opensearch="{{ pillar.search.opensearch.servers }}"

function curlit {
    url=$1
    status_code=$(curl --silent --output /dev/stderr --write-out "%{http_code}" "$@")
    # https://superuser.com/questions/590099/can-i-make-curl-fail-with-an-exitcode-different-than-0-if-the-http-status-code-i
    errcho "opensearch response status code: $status_code"
    if test $status_code -ne 200; then
        exit $status_code
    fi
}

function create_repo {
    errcho "creating repo '$repo' at '$repo_path' for snapshots (idempotent)"
    curlit -XPUT "$opensearch/_snapshot/$repo" -H "Content-Type: application/json" -d '{"type": "fs", "settings": {"location": "'$repo_path'"}}'
}

function decompress_snapshot {
    # assumes snapshot was compressed with the create-snapshot.sh script
    # in this case there is a root directory called 'repo'
    errcho "decompressing snapshot at '$snapshot_path'"
    (
        cd "$repo_path/.."
        tar xzf "$snapshot_path"
    )
}

function close_indices {
    errcho "closing all indices"
    curlit -XPOST "$opensearch/_all/_close"
}

function restore_snapshot {
    errcho "restoring snapshot '$snapshot'"
    curlit -XPOST "$opensearch/_snapshot/$repo/$snapshot/_restore?wait_for_completion=true"
}

function open_indices {
    errcho "opening all indices"
    curlit -XPOST "$opensearch/_all/_open"
}

function demo {
    # simple demonstration app is working
    curl localhost/search | jq .
}

create_repo
decompress_snapshot
close_indices
restore_snapshot
open_indices

echo "---"

demo
