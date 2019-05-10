search:
    aws:
        access_key_id: null
        secret_access_key: null
        region: us-east-1

    # deprecated and is now found in elife.gearman.db
    gearman:
        db:
            name: gearman
            username: gearman
            password: gearman

elife:
    gearman:
        persistent: True
    aws:
        access_key_id: AKIAFAKE
        secret_access_key: fake

api_dummy:
    standalone: False
    pinned_revision_file: /srv/search/api-dummy.sha1
