search-repository:
    builder.git_latest:
        - name: git@github.com:elifesciences/search.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/search/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - fetch_pull_requests: True
        - require:
            - composer

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
            - goaws-init
            - aws-credentials
        - require_in:
            - search-console-ready
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
        - name: composer --no-interaction install --classmap-authoritative --no-dev
        {% elif pillar.elife.env in ['ci', 'end2end', 'continuumtest'] %}
        - name: composer --no-interaction install --classmap-authoritative
        {% else %}
        - name: composer --no-interaction install
        {% endif %}
        - cwd: /srv/search/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-cache

search-console-ready:
    cmd.run:
        - name: ./bin/console --env={{ pillar.elife.env }}
        - cwd: /srv/search
        - user: {{ pillar.elife.deploy_user.username }}
        - timeout: 5 # seconds
        - require:
            - search-composer-install
            - aws-credentials

search-cache-clean:
    cmd.run:
        - name: ./bin/console cache:clear --env={{ pillar.elife.env }}
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/search
        - require:
            - search-console-ready
            - search-cache

search-ensure-index:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'demo', 'end2end', 'continuumtest'] %}
        - name: ./bin/console search:setup --env={{ pillar.elife.env }}
        {% else %}
        - name: ./bin/console search:setup --delete --env={{ pillar.elife.env }}
        {% endif %}
        - cwd: /srv/search/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-console-ready
            - search-cache-clean

# useful for smoke testing the JSON output
search-jq:
    pkg.installed:
        - pkgs:
            - jq

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
        - template: jinja

{% set processes = ['gearman-worker', 'queue-watch'] %}
{% for process in processes %}
search-{{ process }}-service:
    file.managed:
        - name: /etc/init/search-{{ process }}.conf
        - source: salt://search/config/etc-init-search-{{ process }}.conf
        - template: jinja
        - require:
            - aws-credentials
            - search-ensure-index
            - search-cache-clean
{% endfor %}


