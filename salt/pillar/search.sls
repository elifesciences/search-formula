search:
    api:
        url: http://localhost:8080
        requests_batch: 10

    aws:
        endpoint: http://localhost:4100

    opensearch:
        servers: http://localhost:9201
        logging: true
        force_sync: true

    gearman:
        servers: 127.0.0.1
        # deprecated and is now found in elife.gearman.db
        db:
            name: gearman
            username: gearman
            password: gearman

    debug: true
    validate: true
    ttl: 0
    rate_limit_minimum_page: 2

    {% import_yaml "rds-articles.yaml" as rds_articles %}
    rds_articles: {{ rds_articles|yaml }}

    {% import_yaml "reviewed-preprints.yaml" as reviewed_preprints %}
    reviewed_preprints: {{ reviewed_preprints|yaml }}

elife:
    webserver:
        app: caddy

    composer:
        version: 2.2.7

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
