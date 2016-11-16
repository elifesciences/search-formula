{% set processes = {'gearman-worker': 3, 'queue-watch': 1} %}
{% for process, number in processes.iteritems() %}
search-{{ process }}-task:
    file.managed:
        - name: /etc/init/search-{{ process }}.conf
        - source: salt://elife/config/etc-init-multiple-processes.conf
        - template: jinja
        - context:
            process: search-{{ process }}
            number: {{ number }}
        - require:
            - file: search-{{ process }}-service

search-{{ process }}-start:
    cmd.run:
        - name: start search-{{ process }}
        - require:
            - search-{{ process }}-task
{% endfor %}
