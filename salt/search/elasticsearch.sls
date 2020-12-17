{% set has_ext_volume = salt.disk.blkid(pillar.elife.external_volume.device) != {} %}

elasticsearch-repo:
    pkgrepo.managed:
        - humanname: Official Elasticsearch PPA
        - name: deb http://packages.elasticsearch.org/elasticsearch/2.x/debian stable main
        - dist: stable
        - file: /etc/apt/sources.list.d/elasticsearch.list
        - key_url: https://artifacts.elastic.co/GPG-KEY-elasticsearch

elasticsearch:
    group:
        - present

    user:
        - present
        - groups:
            - elasticsearch
        - require:
            - group: elasticsearch

    pkg:
        - installed
        - refresh: True
        - version: 2.4.0
        - require:
            - java8
            - pkgrepo: elasticsearch-repo

    service:
        - running
        - enable: True
        - require:
            - pkg: elasticsearch
            - file: elasticsearch-config
            - group: elasticsearch

elasticsearch-config:
    file.managed:
        - name: /etc/elasticsearch/elasticsearch.yml
        - source: salt://search/config/etc-elasticsearch-elasticsearch.yml
        - user: elasticsearch
        - group: elasticsearch
        - mode: 644
        - template: jinja
        - defaults:
            has_ext_volume: {{ has_ext_volume }}
        - require:
            - pkg: elasticsearch
        - watch_in:
            - service: elasticsearch

elasticsearch-logging-config:
    file.managed:
        - name: /etc/elasticsearch/logging.yml
        - source: salt://search/config/etc-elasticsearch-logging.yml
        - user: elasticsearch
        - group: elasticsearch
        - mode: 644
        - template: jinja
        - require:
            - pkg: elasticsearch
        - watch_in:
            - service: elasticsearch

elasticsearch-create-snapshot-script:
    file.managed:
        - name: /root/create-snapshot.sh
        - source: salt://search/scripts/create-snapshot.sh
        - mode: 755

elasticsearch-restore-snapshot-script:
    file.managed:
        - name: /root/restore-snapshot.sh
        - source: salt://search/scripts/restore-snapshot.sh
        - mode: 755

elasticsearch-logrotate:
    file.managed:
        - name: /etc/logrotate.d/elasticsearch
        - source: salt://search/config/etc-logrotate.d-elasticsearch
        - template: jinja
        - defaults:
            has_ext_volume: {{ has_ext_volume }}
        - requires:
            - user: elasticsearch

elasticsearch-migrate:
    cmd.run:
        - name: |
            systemctl stop elasticsearch
            sleep 5
            mkdir -p /ext/elasticsearch
            mv /var/lib/elasticsearch /ext/elasticsearch
            mv /var/log/elasticsearch /ext/elasticsearch/log

        - onlyif:
            # disk exists
            - test -b {{ pillar.elife.external_volume.device }}

        - unless:
            # already migrated
            - test -d /ext/elasticsearch

        #- require:
        # problematic. end2end and ci will be leaders but wont have this statefile
        #    - mount-external-volume # builder-base.external-volume

        - watch_in:
            - service: elasticsearch

        - require_in:
            - cmd: elasticsearch-ready

elasticsearch-ready:
    cmd.run:
        - name: |
            set -e
            wait_for_port 9200 60
            # 'yellow' is normal for single-node clusters, it takes 3-6 seconds to reach this state
            curl --silent "localhost:9200/_cluster/health/elife_search?wait_for_status=yellow&timeout=10s"
            # the '???' period where elasticsearch is unavailable and the search app fails
            echo "sleeping 25 seconds"
            sleep 25
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - elasticsearch
