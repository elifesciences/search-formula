{% if pillar.elife.webserver.app == "caddy" %}

api-dummy-vhost-dev:
    file.managed:
        - name: /etc/caddy/sites.d/api-dummy-dev
        - source: salt://search/config/etc-caddy-sites.d-api-dummy-dev
        - require:
            - api-dummy-composer-install
            - search-vhost
        - listen_in:
            - service: caddy-server-service
            - service: php-fpm

{% else %}

api-dummy-vhost-dev:
    file.managed:
        - name: /etc/nginx/sites-enabled/api-dummy-dev.conf
        - source: salt://search/config/etc-nginx-sites-enabled-api-dummy-dev.conf
        - require:
            - api-dummy-composer-install
            - search-vhost
        - require_in:
            - cmd: caddy-validate-config
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

{% endif %}
