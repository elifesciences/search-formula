{% set leader = salt['elife.cfg']('project.node', 1) == 1 %}

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

search-cache-clean:
    cmd.run:
        - name: rm -rf var/cache/*
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/search
        - require:
            - search-cache

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
            # see also: search-ensure-index
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

{% for process in ['search-gearman-worker', 'search-queue-watch'] %}
search-{{ process }}-service:
    file.managed:
        {% if salt['grains.get']('oscodename') == 'xenial' %}
        - name: /lib/systemd/system/{{ process }}@.service
        - source: salt://search/config/lib-systemd-system-{{ process }}@.service
        {% else %}
        - name: /etc/init/{{ process }}.conf
        - source: salt://search/config/etc-init-search-{{ process }}.conf
        {% endif %}
        - template: jinja
        - require:
            - aws-credentials-deploy-user
            - search-cache-clean
{% endfor %}

