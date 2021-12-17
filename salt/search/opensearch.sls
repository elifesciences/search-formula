{% set deploy_user = pillar.elife.deploy_user.username %}
{% set image_name = "elifesciences/opensearch:af2596cca804f045720e4abda548ef26cc0a0e76" %}

# not strictly necessary as docker-compose will pull the image,
# but I don't like docker-compose pausing to download the image.
opensearch-image:
    docker_image.present:
        - name: {{ image_name }}
        - force: false # once present don't check remote again
        - require:
            - docker-ready

srv-opensearch:
    file.directory:
        - name: /srv/opensearch
        - user: {{ deploy_user }}
        - group: {{ deploy_user }}

usr-share-opensearch:
    cmd.run:
        - name: |
            set -e
            mkdir -p /usr/share/opensearch/{data,logs}
            chown -R 1000:1000 /usr/share/opensearch
        # run once, permissions should be fine afterwards.
        - unless:
            test -d /usr/share/opensearch/

# 2021-10-21: adapted from https://opensearch.org/docs/latest/opensearch/install/docker/
opensearch-docker-compose:
    file.managed:
        - runas: {{ deploy_user }}
        - name: /srv/opensearch/docker-compose.yml
        - source: salt://search/config/srv-opensearch-docker-compose.yml
        - template: jinja
        - defaults:
            image_name: {{ image_name }}
            # OS/ES recommend setting both to 50% of system RAM.
            # max_heap at 2gb on a 4gb system goes OOM doing a reindex.
            # below values are the same for both ES and OS.
            # todo: we get a warning about this:
            # "initial heap size [268435456] not equal to maximum heap size [1073741824]; this can cause resize pauses and prevents memory locking from locking the entire heap"
            # however until ES is purged min_heap can't be any higher
            min_heap: 256m # mb, -Xms
            max_heap: 1g   # gb, -Xmx
        - require:
            - opensearch-image
            - srv-opensearch

opensearch-custom-config:
    file.managed:
        - runas: {{ deploy_user }}
        - name: /srv/opensearch/custom-opensearch.yml
        - source: salt://search/config/srv-opensearch-custom-opensearch.yml
        - require:
            - srv-opensearch

opensearch-service-file:
    file.managed:
        - runas: {{ deploy_user }}
        - name: /lib/systemd/system/opensearch.service
        - source: salt://search/config/lib-systemd-system-opensearch.service
        - require:
            - opensearch-docker-compose

opensearch:
    service.running:
        - name: opensearch
        - enable: True
        #- init_delay: 20 # just wall time + a bit extra.
        - init_delay: 30 # 2021-11-23: bumped to 30s because it's still not consistently ready across envs
        - require:
            - usr-share-opensearch
            - opensearch-service-file
            - opensearch-custom-config
        # if any of these states change, restart *once*, after everything is done
        - listen:
            - opensearch-custom-config
            - opensearch-docker-compose
            - opensearch-service-file

opensearch-ready:
    cmd.run:
        - runas: {{ deploy_user }}
        # lsh@2021-11: changed api call from "_cluster/health/elife_search" to "_cluster/health".
        # this state needs to complete *before* the 'elife_search' index exists.
        # also, there is no guarantee 'elife_search' index even exists outside of dev env.
        # ---
        # `wait_for_port` doesn't really work with a docker-compose service. 
        # The network is brought up and the port becomes available but nothing is attached until OpenSearch boots.
        # Ubuntu 18.04 version of curl and it's retry logic can't handle this state and considers it a permanent failure.
        # newer versions of curl have a `--retry-all-errors` option that could replace `init_delay` in the `opensearch` state.
        - name: |
            set -e
            wait_for_port 9201 60
            echo "waiting for healthy cluster"
            # 'yellow' is/was normal for single-node ES clusters.
            curl --silent "localhost:9201/_cluster/health?wait_for_status=yellow&timeout=30s"
        - require:
            - opensearch

# ---

opensearch-logrotate:
    file.managed:
        - name: /etc/logrotate.d/opensearch
        - source: salt://search/config/etc-logrotate.d-opensearch
        - template: jinja

opensearch-create-snapshot-script:
    file.managed:
        - name: /root/opensearch-create-snapshot.sh
        - source: salt://search/scripts/opensearch-create-snapshot.sh
        - template: jinja
        - mode: 755

opensearch-restore-snapshot-script:
    file.managed:
        - name: /root/opensearch-restore-snapshot.sh
        - source: salt://search/scripts/opensearch-restore-snapshot.sh
        - template: jinja
        - mode: 755

opensearch-upload-download-snapshot-script:
    file.managed:
        - name: /root/upload-download-snapshot.sh
        - source: salt://search/scripts/upload-download-snapshot.sh
        - template: jinja
        - context:
            aws_access_id: {{ pillar.elife.backups.s3_access }}
            aws_secret_key: {{ pillar.elife.backups.s3_secret }}
            env: {{ pillar.elife.env }}
        - mode: 755
