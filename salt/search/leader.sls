{% if pillar.elife.env in ['dev', 'ci'] %}
search-queue-create:
    cmd.run:
        - name: aws sqs create-queue --region=us-east-1 --queue-name=search--{{ pillar.elife.env }} --endpoint=http://localhost:4100
        - cwd: /home/{{ pillar.elife.deploy_user.username }}
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - goaws
            - aws-cli
            - aws-credentials-deploy-user
        - require_in:
            - cmd: search-console-ready
{% endif %}

search-console-ready:
    cmd.run:
        - name: ./bin/console --env={{ pillar.elife.env }} --no-interaction
        - cwd: /srv/search
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-cache
            - gearman-service
            - opensearch-ready
            - search-composer-install
            - search-configuration-file
            - aws-credentials-deploy-user

search-ensure-index:
    cmd.run:
        # destroy index in dev and ci environments
        - name: |
        {% if pillar.elife.env in ['prod', 'demo', 'end2end', 'continuumtest'] %}
            ./bin/console search:setup --env={{ pillar.elife.env }}
        {% else %}
            ./bin/console search:setup --delete --env={{ pillar.elife.env }}
        {% endif %}
            ./bin/console keyvalue:setup --env={{ pillar.elife.env }}
        - cwd: /srv/search/
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-console-ready
            - search-cache
        - require_in:
            - file: search-vhost
