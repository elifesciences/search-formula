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

search-cache:
    file.directory:
        - name: /srv/search/cache
        - user: {{ pillar.elife.webserver.username }}
        - group: {{ pillar.elife.webserver.username }}
        - dir_mode: 775
        - file_mode: 664
        - recurse:
            - user
            - group
        - require:
            - search-repository

composer-install:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'demo', 'end2end'] %}
        - name: composer1.0 --no-interaction install --classmap-authoritative --no-dev
        {% elif pillar.elife.env in ['ci'] %}
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
        - name: ./bin/console search:setup
        - cwd: /srv/search/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - composer-install

search-nginx-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/search.conf
        - source: salt://search/config/etc-nginx-sites-enabled-search.conf
        - template: jinja
        - require:
            - nginx-config
            - composer-install
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

search-gearman-worker-service:
    file.managed:
        - name: /etc/init/search-gearman-worker.conf
        - source: salt://search/config/etc-init-search-gearman-worker.conf
        - template: jinja
        - require:
            - composer-install
