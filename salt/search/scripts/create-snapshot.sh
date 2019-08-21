#!/bin/bash
# creates a repository in Elasticsearch to store a snapshot
# creates a snapshot with the first given parameter
# tars and compresses the snapshot
# moves the compressed snapshot to /tmp/
# emits the path to the compressed snapshot file

set -eu

snapshot="$1"

repo="repo"
repo_path="/var/lib/elasticsearch/$repo"
elasticsearch="127.0.0.1:9200"

function errcho { 
    echo "$@" 1>&2; 
}

function curlit {
    url=$1
    status_code=$(curl --silent --output /dev/stderr --write-out "%{http_code}" "$@")
    # https://superuser.com/questions/590099/can-i-make-curl-fail-with-an-exitcode-different-than-0-if-the-http-status-code-i
    errcho "elasticsearch response status code: $status_code"
    if test $status_code -ne 200; then
        exit $status_code
    fi
}

function create_repo {
    errcho "creating repo '$repo' at '$repo_path' for snapshots (idempotent)"
    curlit -XPUT "$elasticsearch/_snapshot/$repo" -d '{"type": "fs", "settings": {"location": "'$repo_path'"}}'
}

function create_snapshot {
    # snapshots are incremental, so just the difference from the previous snapshot are stored
    errcho "creating snapshot with '$snapshot' (blocking call, may take a while depending on size of snapshot)"
    curlit -XPUT "$elasticsearch/_snapshot/$repo/$snapshot?wait_for_completion=true"
}

function compress_snapshot {
    errcho "compressing snapshot at '$repo_path'"
    output_fname="$snapshot.tar.gz"
    tar -czf "$output_fname" -C "$repo_path/.." "$repo"
    echo $(realpath $output_fname)
}

create_repo
create_snapshot
compress_snapshot
