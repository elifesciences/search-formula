{% set deploy_user = pillar.elife.deploy_user.username %}
{% set image_name = "opensearchproject/opensearch:1.1.0" %}

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
        - require:
            - opensearch-service-file
            - opensearch-custom-config
        # if any of these states change, restart *once*, after everything is done
        - listen:
            - opensearch-custom-config
            - opensearch-docker-compose
            - opensearch-service-file
