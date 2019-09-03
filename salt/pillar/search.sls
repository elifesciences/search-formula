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

    multiservice:
        services:
            search-gearman-worker:
                service_template: search-gearman-worker-service
                num_processes: 3
            search-queue-watch:
                service_template: search-queue-watch-service
                num_processes: 3

api_dummy:
    standalone: False
    pinned_revision_file: /srv/search/api-dummy.sha1
