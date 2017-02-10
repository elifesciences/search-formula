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
    cmd.run:
        - name: start search-processes
        - require:
            - search-processes-task
