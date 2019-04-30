{% set processes = {'search-gearman-worker': 3, 'search-queue-watch': 3} %}

{% for process, number in processes.iteritems() %}
{{process}}-old-restart-tasks:
    file.absent:
        - name: /etc/init/{{ process }}s.conf
{% endfor %}


search-processes-task:
    file.managed:
        - name: /etc/init/search-processes.conf
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}
        - require:
            {% for process, _number in processes.iteritems() %}
            - file: {{ process }}-service
            {% endfor %}

search-processes-start:
    service.running:
        - name: search-processes
        - require:
            - search-processes-task
        - watch:
            - aws-credentials-deploy-user

search-gearman-worker-stop-all-task:
    file.managed:
        - name: /etc/init/search-gearman-worker-stop-all.conf
        - source: salt://elife/config/etc-init-multiple-stop.conf
        - template: jinja
        - context:
            processes: {{ {'search-gearman-worker': processes['search-gearman-worker']} }}
        - require:
            - search-processes-task
