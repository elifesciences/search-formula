#!/bin/bash
set -eu

op=$1

id={{ aws_access_id }}
key={{ aws_secret_key }}
env={{ env }}
today=$(date -I)

backup="$today.opensearch.tar.gz"

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
    AWS_ACCESS_KEY_ID="$id" AWS_SECRET_ACCESS_KEY="$key" aws s3 cp "$backup" "s3://elife-app-backups/search/adhoc/$today-$env-$backup"
fi

if [ "$op" = "download" ]; then
    AWS_ACCESS_KEY_ID="$id" AWS_SECRET_ACCESS_KEY="$key" aws s3 cp "s3://elife-app-backups/search/adhoc/$today-$env-$backup" "$backup"
fi
