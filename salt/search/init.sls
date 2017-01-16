search-repository:
    builder.git_latest:
        - name: git@github.com:stephenwf/search.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/search/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - fetch_pull_requests: True
        - require:
            - php-composer-1.0
            - php-puli-latest

    file.directory:
        - name: /srv/search
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - builder: search-repository

{% if pillar.elife.env in ['dev', 'ci'] %}
search-queue-create:
    cmd.run:
        - name: aws sqs create-queue --region=us-east-1 --queue-name=search--{{ pillar.elife.env }} --endpoint=http://localhost:4100
        - cwd: /home/{{ pillar.elife.deploy_user.username }}
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-repository
            - aws-credentials-cli
{% endif %}

# files and directories must be readable and writable by both elife and www-data
# they are both in the www-data group, but the g+s flag makes sure that
# new files and directories created inside have the www-data group
search-cache:
    file.directory:
        - name: /srv/search/var
        - user: {{ pillar.elife.webserver.username }}
        - group: {{ pillar.elife.webserver.username }}
        - dir_mode: 775
        - file_mode: 664
        - recurse:
            - user
            - group
            - mode
        - require:
            - search-repository

    cmd.run:
        - name: chmod -R g+s /srv/search/var
        - require:
            - file: search-cache

search-composer-install:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'demo'] %}
        - name: composer1.0 --no-interaction install --classmap-authoritative --no-dev
        {% elif pillar.elife.env in ['ci', 'end2end'] %}
        - name: composer1.0 --no-interaction install --classmap-authoritative
        {% else %}
        - name: composer1.0 --no-interaction install
        {% endif %}
        - cwd: /srv/search/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-cache


search-ensure-index:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'demo', 'end2end'] %}
        - name: ./bin/console search:setup --env={{ pillar.elife.env }}
        {% else %}
        - name: ./bin/console search:setup --delete --env={{ pillar.elife.env }}
        {% endif %}
        - cwd: /srv/search/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-composer-install
            - aws-credentials-cli

search-cache-clean:
    cmd.run:
        - name: ./bin/console cache:clear --env={{ pillar.elife.env }}
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/search
        - require:
            - search-cache
            - search-composer-install

# useful for smoke testing the JSON output
search-jq:
    pkg.installed:
        - pkgs:
            - jq

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
            stop gearman-job-server
            start gearman-job-server
        - onchanges:
            - file: gearman-configuration

search-nginx-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/search.conf
        - source: salt://search/config/etc-nginx-sites-enabled-search.conf
        - template: jinja
        - require:
            - nginx-config
            - search-composer-install
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

syslog-ng-search-logs:
    file.managed:
        - name: /etc/syslog-ng/conf.d/search.conf
        - source: salt://search/config/etc-syslog-ng-conf.d-search.conf
        - template: jinja
        - require:
            - pkg: syslog-ng
            - search-composer-install
        - listen_in:
            - service: syslog-ng

logrotate-search-logs:
    file.managed:
        - name: /etc/logrotate.d/search
        - source: salt://search/config/etc-logrotate.d-search

{% set processes = ['gearman-worker', 'queue-watch'] %}
{% for process in processes %}
search-{{ process }}-service:
    file.managed:
        - name: /etc/init/search-{{ process }}.conf
        - source: salt://search/config/etc-init-search-{{ process }}.conf
        - template: jinja
        - require:
            - aws-credentials-cli
            - search-ensure-index
            - search-cache-clean
{% endfor %}

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

