# Adapted from:
# - https://github.com/elifesciences/builder-base-formula/blob/master/elife/elasticsearch.sls

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
            - oracle-java8-installer
            - pkgrepo: elasticsearch-repo

    service:
        - running
        - enable: True
        - require:
            - oracle-java8-installer
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
        - requires:
            - user: elasticsearch

elasticsearch-ready:
    cmd.run:
        - name: wait_for_port 9200 60
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - elasticsearch
