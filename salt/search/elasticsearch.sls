# Adapted from:
# - https://github.com/elifesciences/builder-base-formula/blob/master/elife/elasticsearch.sls

elasticsearch-repo:
    pkgrepo.managed:
        - humanname: Official Elasticsearch PPA
        - name: deb https://artifacts.elastic.co/packages/5.x/apt stable main
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
        - version: 5.0
        - require:
            - pkg: oracle-java8-installer
            - pkgrepo: elasticsearch-repo

    service:
        - running
        - enable: True
        - require:
            - pkg: oracle-java8-installer
            - pkg: elasticsearch
            - file: /etc/elasticsearch/elasticsearch.yml
            - group: elasticsearch

elasticsearch-config:
    file.managed:
        - name: /etc/elasticsearch/elasticsearch.yml
        - source: salt://search/config/etc-elasticsearch-elasticsearch.yml
        - user: elasticsearch
        - group: elasticsearch
        - mode: 644
        - template: jinja
