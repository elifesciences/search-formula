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
        - require:
            - pkg: oracle-java8-installer
            - pkgrepo: elasticsearch-repo

    service:
        - running
        - enable: True
        - require:
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

# The GUI is now a stand-alone component and not a plugin/
# This has increased the complexity of install (last attempt below).
# For now, unless there are strong objections, I've shelved the GUI.

#elasticsearch-gui-repo:
#    builder.git_latest:
#        - name: git@github.com:mobz/elasticsearch-head.git
#        - identity: {{ pillar.elife.projects_builder.key or '' }}
#        - target: /usr/share/elasticsearch/plugins/elasticsearch-head
#        - force_fetch: True
#        - force_checkout: True
#        - force_reset: True
#        - fetch_pull_requests: True
#        - require:
#            - pkg: elasticsearch
#
#elasticsearch-gui-install:
#    cmd.run:
#        - cwd: /usr/share/elasticsearch/plugins/elasticsearch-head
#        - name: npm install
#        - require:
#            - pkg: elasticsearch
#        - unless:
#            - test -d /usr/share/elasticsearch/plugins/elasticsearch-head/node_modules
#
#node-grunt:
#    cmd.run:
#        - name: npm install -g grunt
#        - require:
#            - pkg: elasticsearch
#
#elasticsearch-gui-run:
#    cmd.run:
#        - cwd: /usr/share/elasticsearch/plugins/
#        - name: grunt server
#        - require:
#            - pkg: elasticsearch
