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

elasticsearch-ready:
    cmd.run:
        - name: |
            timeout 60 sh -c 'while ! nc -q0 -w1 -z localhost 9200 </dev/null >/dev/null 2>&1; do sleep 1; done'
        - require:
            - elasticsearch
