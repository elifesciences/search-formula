api-dummy-nginx-vhost-dev:
    file.managed:
        - name: /etc/nginx/sites-enabled/api-dummy-dev.conf
        - source: salt://search/config/etc-nginx-sites-enabled-api-dummy-dev.conf
        - require:
            - api-dummy-composer-install
            - search-nginx-vhost
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm
