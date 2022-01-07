#!/bin/bash
# downloads/uploads a snapshot to the elife-app-backups S3 bucket.
# note: you have to specify the environment when downloading a snapshot into a different environment.
# note: you have to specify the datestamp when downloading a snapshot older than today.
#
# download usage:
#   ./upload-download-snapshot.sh download some-snapshot.tar.gz
#   ./upload-download-snapshot.sh download some-snapshot.tar.gz continuumtest
#   ./upload-download-snapshot.sh download some-snapshot.tar.gz continuumtest 2021-12-31
#
# upload usage:
#    ./upload-download-snapshot.sh upload some-snapshot.tar.gz

set -eu

op="$1" # "upload" or "download"
backup="$2" # "name-of-snapshot-file.tar.gz"
env="${3:-{{ env }}}" # "ci" or "continuumtest" or "end2end" or "prod" etc. defaults to current environment.

id={{ aws_access_id }}
key={{ aws_secret_key }}
today=$(date -I)
datestamp="${4:-today}"

if [ ! -d venv ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install pip wheel --upgrade
pip install awscli

if [ "$op" = "upload" ]; then
    if [ ! -f "$backup" ]; then
        echo "backup file '$backup' not found"
        exit 1
    fi
    AWS_ACCESS_KEY_ID="$id" AWS_SECRET_ACCESS_KEY="$key" aws s3 cp "$backup" "s3://elife-app-backups/search/adhoc/$datestamp-$env-$backup"
fi

if [ "$op" = "download" ]; then
    AWS_ACCESS_KEY_ID="$id" AWS_SECRET_ACCESS_KEY="$key" aws s3 cp "s3://elife-app-backups/search/adhoc/$datestamp-$env-$backup" "$backup"
fi
