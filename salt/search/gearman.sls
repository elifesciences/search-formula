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

gearman-configuration-old:
    file.absent:
        - name: /etc/default/gearman-job-server

gearman-configuration:
    file.managed:
        - name: /etc/gearman.conf
        - source: salt://search/config/etc-gearman.conf
        - template: jinja
        - require:
            - gearman-daemon
            - gearman-db

gearman-service:
    {% if salt['grains.get']('oscodename') == 'trusty' %}
    cmd.run:
        # I do not trust anymore Upstart to see changes to init scripts when using `restart` alone
        - name: |
            stop gearman-job-server
            start gearman-job-server
        - onchanges:
            - gearman-configuration
            
    {% else %}
    service.running:
        - name: gearman-job-server
        - enable: True
        - require:
            - postgresql-ready
            - gearman-db
            - gearman-db-user
        - watch: # restart immediately
            - gearman-configuration
    {% endif %}

{% if pillar.elife.env in ['dev', 'ci'] %}
clear-gearman:
    cmd.run:
        - env:
            - PGPASSWORD: {{ pillar.search.gearman.db.password }}
        - name: |
            psql --no-password {{ pillar.search.gearman.db.name}} {{ pillar.search.gearman.db.username }} -c 'DELETE FROM queue'
        - watch_in:
            - gearman-service
        - require:
            - gearman-daemon
            - gearman-service
{% endif %}

