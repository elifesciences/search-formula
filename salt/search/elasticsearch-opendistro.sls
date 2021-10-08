# https://opendistro.github.io/for-elasticsearch-docs/docs/install/deb/
elasticsearch-opendistro-repo:
    pkgrepo.managed:
        - humanname: Official Elasticsearch OpenDistro PPA
        - name: deb https://d3g5vo6xdbdb9a.cloudfront.net/apt stable main
        - dist: stable
        - file: /etc/apt/sources.list.d/opendistroforelasticsearch.list
        - key_url: https://d3g5vo6xdbdb9a.cloudfront.net/GPG-KEY-opendistroforelasticsearch

old-elasticsearch-removed:
    service.dead:
        - name: elasticsearch
        
    pkg.purged:
        - name: elasticsearch
        - require: 
            - service: old-elasticsearch-removed

# there is no upgrade path from 2.4 to 7.10, any data must be reindexed.
# delete the indices if they exist. 
# if we don't the elasticsearch service will fail to start.
old-elasticsearch-data-removed:
    file.absent:
        - name: /var/lib/elasticsearch/elasticsearch
        - require:
            - old-elasticsearch-removed

elasticsearch-oss:
    cmd.run:
        - cwd: /tmp
        - name: |
            set -e
            wget --quiet https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-7.10.2-amd64.deb
            dpkg -i elasticsearch-oss-7.10.2-amd64.deb
        - require:
            - old-elasticsearch-removed
        - unless:
            # file already downloaded
            - test -f elasticsearch-oss-7.10.2-amd64.deb

elasticsearch:
    group.present:
        - name: elasticsearch

    user.present:
        - name: elasticsearch
        - groups:
            - elasticsearch
        - require:
            - group: elasticsearch

    pkg.installed:
        - name: opendistroforelasticsearch
        - refresh: True
        # https://opendistro.github.io/for-elasticsearch-docs/version-history/
        # 1.13.2 corresponds to 7.10.2 of ES
        - version: 1.13.2-1
        - require:
            - java11
            - elasticsearch-oss
            - pkgrepo: elasticsearch-opendistro-repo

    service.running:
        - name: elasticsearch
        - enable: True
        - require:
            - old-elasticsearch-data-removed
            - pkg: elasticsearch
            - file: elasticsearch-config
            - group: elasticsearch

opendistro-performance-analyzer:
    # should the analyzer find itself running without this file, it will emit an error every 1-2 seconds
    file.managed:
        - name: /usr/share/elasticsearch/data/batch_metrics_enabled.conf
        - contents: false
        - require:
            - pkg: elasticsearch
    
    # this version is constantly emitting noise to the logs
    service.dead:
        - name: opendistro-performance-analyzer
        - require:
            - pkg: elasticsearch

# ----

elasticsearch-config:
    file.managed:
        - name: /etc/elasticsearch/elasticsearch.yml
        - source: salt://search/config/etc-elasticsearch-elasticsearch.yml--opendistro
        - user: elasticsearch
        - group: elasticsearch
        - mode: 644
        - template: jinja
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

elasticsearch-upload-download-snapshot-script:
    file.managed:
        - name: /root/upload-download-snapshot.sh
        - source: salt://search/scripts/upload-download-snapshot.sh
        - template: jinja
        - context:
            aws_access_id: {{ pillar.elife.backups.s3_access }}
            aws_secret_key: {{ pillar.elife.backups.s3_secret }}
            env: {{ pillar.elife.env }}
        - mode: 755

elasticsearch-logrotate:
    file.managed:
        - name: /etc/logrotate.d/elasticsearch
        - source: salt://search/config/etc-logrotate.d-elasticsearch
        - template: jinja
        - requires:
            - user: elasticsearch

elasticsearch-ready:
    cmd.run:
        - name: |
            set -e
            wait_for_port 9200 60
            # 'yellow' is normal for single-node clusters, it takes 3-6 seconds to reach this state
            curl --silent --insecure "http://localhost:9200/_cluster/health/elife_search?wait_for_status=yellow&timeout=10s"
            # the '???' period where elasticsearch is unavailable and the search app fails
            echo "sleeping 25 seconds"
            sleep 25
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - elasticsearch
