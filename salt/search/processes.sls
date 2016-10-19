{% set number = 3 %}
search-gearman-workers-task:
    file.managed:
        - name: /etc/init/search-gearman-workers.conf
        - source: salt://elife/config/etc-init-multiple-processes.conf
        - template: jinja
        - context:
            process: search-gearman-worker
            number: {{ number }}
        - require:
            - file: search-gearman-worker-service

search-gearman-workers-start:
    cmd.run:
        - name: start search-gearman-workers
        - require:
            - search-gearman-workers-task
