elasticsearch-repo:
    pkgrepo.absent:
        - name: deb http://packages.elasticsearch.org/elasticsearch/2.x/debian stable main

elasticsearch-service:
    service.dead:
        - name: elasticsearch
        - require_in:
            - elasticsearch

elasticsearch:
    user:
        - absent

    group:
        - absent
        - require:
            - user: elasticsearch

    pkg:
        - purged

elasticsearch-config:
    file.absent:
        - name: /etc/elasticsearch/elasticsearch.yml
        #- source: salt://search/config/etc-elasticsearch-elasticsearch.yml

elasticsearch-logging-config:
    file.absent:
        - name: /etc/elasticsearch/logging.yml
        #- source: salt://search/config/etc-elasticsearch-logging.yml

elasticsearch-create-snapshot-script:
    file.absent:
        - name: /root/create-snapshot.sh
        #- source: salt://search/scripts/create-snapshot.sh

elasticsearch-restore-snapshot-script:
    file.absent:
        - name: /root/restore-snapshot.sh
        #- source: salt://search/scripts/restore-snapshot.sh

elasticsearch-logrotate:
    file.absent:
        - name: /etc/logrotate.d/elasticsearch
        #- source: salt://search/config/etc-logrotate.d-elasticsearch

elasticsearch-ready:
    cmd.run:
        - name: echo "elasticsearch removed"
        - require:
            - elasticsearch-logrotate
            - elasticsearch-restore-snapshot-script
            - elasticsearch-create-snapshot-script
            - elasticsearch-logging-config
            - elasticsearch-config
            - elasticsearch
            - elasticsearch-repo
