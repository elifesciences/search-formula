#!/bin/bash
# creates a 'repository' in Opensearch to store a snapshot.
# creates a snapshot using the name given in the first parameter.
# tars and compresses the snapshot.
# moves the compressed snapshot to /tmp/
# emits the path to the compressed snapshot file

set -eu

snapshot="$1"

# "Before you can take a snapshot, you have to “register” a snapshot repository."
repo="snapshots"
repo_path="/usr/share/opensearch/data/$repo"
opensearch="127.0.0.1:9201"

function errcho { 
    echo "$@" 1>&2; 
}

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

function create_snapshot {
    # snapshots are incremental, so just the difference from the previous snapshot are stored
    errcho "creating snapshot with '$snapshot' (blocking call, may take a while depending on size of snapshot)"
    curlit -XPUT "$opensearch/_snapshot/$repo/$snapshot?wait_for_completion=true"
}

function compress_snapshot {
    errcho "compressing snapshot at '$repo_path'"
    output_fname="$snapshot.opensearch.tar.gz"
    tar -czf "$output_fname" -C "$repo_path/.." "$repo"
    echo $(realpath $output_fname)
}

create_repo
create_snapshot
compress_snapshot
