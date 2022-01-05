{% set leader = salt['elife.cfg']('project.node', 1) == 1 %}
{% set www_user = pillar.elife.webserver.username %}
{% set deploy_user = pillar.elife.deploy_user.username %}

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
        - require:
            - builder: search-repository

# files and directories must be readable and writable by both elife and www-data
# they are both in the www-data group, but the g+s flag makes sure that
# new files and directories created inside have the www-data group
search-cache:
    file.directory:
        - name: /srv/search/var
        - user: {{ www_user }}
        - group: {{ www_user }}
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
        - runas: {{ deploy_user }}
        - require:
            - search-cache

search-cache-clean:
    cmd.run:
        - name: rm -rf var/cache/*
        - runas: {{ deploy_user }}
        - cwd: /srv/search
        - require:
            - search-cache

search-configuration-file-elasticsearch:
    file.managed:
        - user: {{ deploy_user }}
        - name: /srv/search/elasticsearch-config.php
        - source: salt://search/config/srv-search-config.php
        - template: jinja
        - defaults:
            servers: {{ pillar.search.elasticsearch.servers }}
            logging: {{ pillar.search.elasticsearch.logging }}
            force_sync: {{ pillar.search.elasticsearch.force_sync }}
        - require:
            - search-repository

search-configuration-file-opensearch:
    file.managed:
        - user: {{ deploy_user }}
        - name: /srv/search/opensearch-config.php
        - source: salt://search/config/srv-search-config.php
        - template: jinja
        - defaults:
            servers: {{ pillar.search.opensearch.servers }}
            logging: {{ pillar.search.opensearch.logging }}
            force_sync: {{ pillar.search.opensearch.force_sync }}
        - require:
            - search-repository

search-configuration-file:
    cmd.run:
        - runas: {{ deploy_user }}
        - cwd: /srv/search
        - name: |
            if [ -e .opensearch ]; then
                ln -sfT opensearch-config.php config.php
            else
                ln -sfT elasticsearch-config.php config.php
            fi

        - require:
            - search-configuration-file-elasticsearch
            - search-configuration-file-opensearch

        # lsh@2022-01-05: using the file.symlink and testing for a file's existence through salt modules version of this state has proven unreliable. 
        # simply restarting the server on each highstate regardless of any change to the config will hold us until elasticsearch is removed. 

        # lsh@2022-01-04: added after non-deterministic smoke tests while switching to opensearch
        # restart nginx and php if the opensearch config changes
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

search-nginx-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/search.conf
        - source: salt://search/config/etc-nginx-sites-enabled-search.conf
        - template: jinja
        - require:
            - nginx-config
            # not a strong requisite.
            # this is just a config file. listen_in will take care of any eventual service restart
            #- search-composer-install
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

