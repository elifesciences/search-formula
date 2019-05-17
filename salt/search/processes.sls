{% set processes = {'search-gearman-worker': 3, 'search-queue-watch': 3} %}

{% for process, number in processes.iteritems() %}
{{process}}-old-restart-tasks:
    file.absent:
        - name: /etc/init/{{ process }}s.conf
{% endfor %}



{% if salt['grains.get']('osrelease') == '14.04' %}

search-processes-task:
    file.managed:
        - name: /etc/init/search-processes.conf
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}
        - require:
            {% for process in processes %}
            - file: search-{{ process }}-service
            {% endfor %}

search-processes-start:
    cmd.run:
        - name: start search-processes
        - require:
            - aws-credentials
            - search-ensure-index
            - search-cache-clean
            - search-processes-task

search-gearman-worker-stop-all-task:
    file.managed:
        - name: /etc/init/search-gearman-worker-stop-all.conf
        - source: salt://elife/config/etc-init-multiple-stop.conf
        - template: jinja
        - context:
            processes: {{ {'search-gearman-worker': processes['search-gearman-worker']} }}
        - require:
            - search-processes-task





{% else %}





{% for process in processes %}
search-{{ process }}-service:
    file.managed:
        - name: /lib/systemd/system/{{ process }}@.service
        - source: salt://search/config/lib-systemd-system-{{ process }}@.service
        - template: jinja
{% endfor %}

# manages many search-process services
search-processes-script:
    file.managed:
        - name: /opt/search-processes.sh
        - source: salt://elife/templates/systemd-multiple-processes-parallel.sh
        - template: jinja
        - mode: 740
        - context:
            processes: {{ processes }}

# this is a service that calls the script at /opt/search-processes.sh
# that script in turn calls a templated service N times
search-processes-start:
    file.managed:
        - name: /lib/systemd/system/search-processes.service
        - source: salt://search/config/lib-systemd-system-search-processes.service

    service.running:
        - name: search-processes
        - require:
            - file: search-processes-start
            - search-processes-script
            - aws-credentials
            - search-ensure-index
            - search-cache-clean
            {% for process in processes %}
            - search-{{ process }}-service
            {% endfor %}

{% endif %}
