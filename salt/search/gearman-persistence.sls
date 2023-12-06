# requires elife.postgresql, elife.gearman

{% set osrelease = salt['grains.get']('osrelease') %}
{% set leader = salt['elife.cfg']('project.node', 1) == 1 %}

{% if leader %}
gearman-db-user:
    postgres_user.present:
        - name: {{ pillar.search.gearman.db.username }}
        - encrypted: scram-sha-256
        - password: {{ pillar.search.gearman.db.password }}
        - refresh_password: True
        - db_user: {{ pillar.elife.db_root.username }}
        - db_password: {{ pillar.elife.db_root.password }}
        - createdb: True
        - require:
            - postgresql-ready

gearman-db:
    postgres_database.present:
        - name: {{ pillar.search.gearman.db.name }}
        - owner: {{ pillar.search.gearman.db.username }}
        - db_user: {{ pillar.search.gearman.db.username }}
        - db_password: {{ pillar.search.gearman.db.password }}
        - require:
            - postgres_user: gearman-db-user

gearman-service:
    file.managed:
        - name: /lib/systemd/system/gearman-job-server.service
        - source: salt://search/config/lib-systemd-system-gearman-job-server.service
        - template: jinja
        - require:
            - pkg: gearman-daemon # elife.gearman-server.sls

    service.running:
        - name: gearman-job-server
        - enable: True
        - require:
            - postgresql-ready
            - gearman-db
            - file: gearman-service
        - watch:
            - file: gearman-service

{% if pillar.elife.env in ['dev', 'ci'] %}
clear-gearman:
    cmd.run:
        - env:
            - PGPASSWORD: {{ pillar.search.gearman.db.password }}
        - name: |
            set -e
            psql --no-password -U {{ pillar.search.gearman.db.username }} {{ pillar.search.gearman.db.name }} -c "DELETE FROM queue"
            systemctl restart gearman-job-server
        - require:
            - gearman-daemon
            - gearman-configuration

{% endif %} # end dev/ci
{% endif %} # end leader
