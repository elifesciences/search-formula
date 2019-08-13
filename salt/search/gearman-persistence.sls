# requires elife.postgresql, elife.gearman

{% set leader = salt['elife.cfg']('project.node', 1) == 1 %}
{% if leader %}
gearman-db-user:
    postgres_user.present:
        - name: {{ pillar.search.gearman.db.username }}
        - encrypted: True
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

gearman-configuration:
    file.managed:
        - name: /etc/default/gearman-job-server
        - source: salt://search/config/etc-default-gearman-job-server
        - template: jinja
        - require:
            - gearman-daemon
            - gearman-db

    cmd.run:
        # I do not trust anymore Upstart to see changes to init scripts when using `restart` alone
        - name: |
            systemctl stop gearman-job-server || stop gearman-job-server
            systemctl start gearman-job-server || start gearman-job-server
        - onchanges:
            - file: gearman-configuration
{% endif %}

{% if leader %}
{% if pillar.elife.env in ['dev', 'ci'] %}
clear-gearman:
    cmd.run:
        - env:
            - PGPASSWORD: {{ pillar.search.gearman.db.password }}
        - name: |
            psql --no-password {{ pillar.search.gearman.db.name}} {{ pillar.search.gearman.db.username }} -c 'DELETE FROM queue'
            sudo service gearman-job-server restart
        - require:
            - gearman-daemon
            - gearman-configuration
{% endif %}
{% endif %}

