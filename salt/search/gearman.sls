# this is to be migrated out to builder-base as well. 
gearman-service:
    {% if salt['grains.get']('osrelease') == '14.04' %}
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
            {% if pillar.elife.env in ['dev', 'ci'] %}
            - cmd: clear-gearman
            {% endif %}
    {% endif %}
