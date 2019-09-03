{% if pillar.elife.env in ['dev', 'ci'] %}
search-queue-create:
    cmd.run:
        - name: aws sqs create-queue --region=us-east-1 --queue-name=search--{{ pillar.elife.env }} --endpoint=http://localhost:4100
        - cwd: /home/{{ pillar.elife.deploy_user.username }}
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - goaws
            - aws-credentials-deploy-user
        - require_in:
            - cmd: search-console-ready
{% endif %}

search-console-ready:
    cmd.run:
        - name: ./bin/console --env={{ pillar.elife.env }}
        - cwd: /srv/search
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - elasticsearch-ready
            - search-composer-install
            - aws-credentials-deploy-user

search-ensure-index:
    cmd.run:
        - name: |
        {% if pillar.elife.env in ['prod', 'demo', 'end2end', 'continuumtest'] %}
            ./bin/console search:setup --env={{ pillar.elife.env }}
        {% else %}
            ./bin/console search:setup --delete --env={{ pillar.elife.env }}
        {% endif %}
            # TODO: add --delete support ans use it in dev/ci
            ./bin/console keyvalue:setup --env={{ pillar.elife.env }}
        - cwd: /srv/search/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - search-console-ready
            - search-cache-clean
        - require_in:
            - file: search-nginx-vhost
