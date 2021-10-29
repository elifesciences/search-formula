{% set deploy_user = pillar.elife.deploy_user.username %}
# todo: pin this at a specific revision
{% set image_name = "elifesciences/opensearch:latest" %}

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
    file.directory:
        - name: /usr/share/opensearch
        # 'ubuntu' or 'vagrant' user on host. 'opensearch' user ID within guest.
        - user: 1000
        - group: 1000

# 2021-10-21: adapted from https://opensearch.org/docs/latest/opensearch/install/docker/
opensearch-docker-compose:
    file.managed:
        - runas: {{ deploy_user }}
        - name: /srv/opensearch/docker-compose.yml
        - source: salt://search/config/srv-opensearch-docker-compose.yml
        - template: jinja
        - defaults:
            image_name: {{ image_name }}
            # recommend setting both to 50% of system RAM
            # todo: revisit these values
            min_heap: 512m
            max_heap: 512m
        - require:
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
        - require:
            - usr-share-opensearch
            - opensearch-service-file
            - opensearch-custom-config
        # if any of these states change, restart *once*, after everything is done
        - listen:
            - opensearch-custom-config
            - opensearch-docker-compose
            - opensearch-service-file

# todo: needs more work
opensearch-ready:
    cmd.run:
        - runas: {{ deploy_user }}
        - name: |
            set -e
            wait_for_port 9201 60
            # 'yellow' is normal for single-node clusters, it takes 3-6 seconds to reach this state
            #curl --silent "localhost:9201/_cluster/health/elife_search?wait_for_status=yellow&timeout=10s"
            curl --silent "localhost:9201/_cluster/health/elife_search?wait_for_status=yellow&timeout=25s"
            # the '???' period where elasticsearch is unavailable and the search app fails
            #echo "sleeping 25 seconds"
            #sleep 25
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
        - mode: 755

opensearch-restore-snapshot-script:
    file.managed:
        - name: /root/opensearch-restore-snapshot.sh
        - source: salt://search/scripts/opensearch-restore-snapshot.sh
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
