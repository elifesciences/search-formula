{% set leader = salt['elife.cfg']('project.node', 1) == 1 %}
{% set www_user = pillar.elife.webserver.username %}
{% set deploy_user = pillar.elife.deploy_user.username %}
{% set osrelease = salt['grains.get']('osrelease') %}

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
        - user: {{ deploy_user }}
        - group: {{ deploy_user }}
        - recurse:
            - user
            - group
        - silent: true
        - require:
            - builder: search-repository

# tell the `search-cache-clean` state not to delete the .gitkeep file.
# bit weird.
search-cache-clean.gitkeep:
  file.managed:
     - name: /srv/search/var/cache/.gitkeep
     - create: False
     - replace: False
     - require_in:
        - search-cache-clean

search-cache-clean:
    file.directory:
        - name: /srv/search/var/cache/
        - clean: true
        - silent: true
        - onlyif:
            # only clean the cache dir if it exists.
            # lsh@2023-12-06: moved this state above `search-cache` to 
            # avoid spending time setting mode bits on files that are then deleted.
            - test -d /srv/search/var/cache

# files and directories must be readable and writable by both elife and www-data.
# they are both in the www-data group, but the g+s flag ensures that new files and 
# directories created inside have the www-data group.
search-cache:
    file.directory:
        - name: /srv/search/var
        # lsh@2023-12-06: errors starting when owner isn't elife
        # "PHP Fatal error:  Uncaught JMS\Serializer\Exception\InvalidArgumentException: The cache directory "/srv/search/src/Search/../../var/cache" is not writable."
        # search-console-ready > cmd.run > ./bin/console --env=dev --no-interaction
        - user: {{ deploy_user }} # {{ www_user }}
        - group: {{ www_user }}
        - dir_mode: 775
        - file_mode: 664
        - recurse:
            - user
            - group
            - mode
        - silent: true
        - require:
            - search-repository
            - search-cache-clean

    cmd.run:
        # all new files in directory will inherit the group owner (www-user) of the directory
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
        - runas: {{ deploy_user }}
        - require:
            - search-cache

search-configuration-file:
    file.managed:
        - user: {{ deploy_user }}
        - name: /srv/search/config.php
        - source: salt://search/config/srv-search-config.php
        - template: jinja
        - defaults:
            servers: {{ pillar.search.opensearch.servers }}
            logging: {{ pillar.search.opensearch.logging }}
            force_sync: {{ pillar.search.opensearch.force_sync }}
        - require:
            - search-repository

{% if pillar.elife.webserver.app == "caddy" %}

search-vhost:
    file.managed:
        - name: /etc/caddy/sites.d/search
        - source: salt://search/config/etc-caddy-sites.d-search
        - template: jinja
        - require:
            - caddy-config
        - require_in:
            - cmd: caddy-validate-config
        - listen_in:
            - service: caddy-server-service
            - service: php-fpm

{% else %}

search-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/search.conf
        - source: salt://search/config/etc-nginx-sites-enabled-search.conf
        - template: jinja
        - require:
            - nginx-config
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

{% endif %}

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

# would be nice, but I can't guarantee it will run last.
#smoke-tests:
#    cmd.run:
#        - cwd: /srv/search
#        - name: ./smoke_tests.sh
#        - require:
#            - search-vhost

