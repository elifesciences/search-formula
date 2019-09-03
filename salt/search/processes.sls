{% if salt['grains.get']('osrelease') == '14.04' %}

{% set processes = {'search-gearman-worker': 3, 'search-queue-watch': 3} %}

{% for process in processes %}
{{ process }}-old-restart-tasks:
    file.absent:
        - name: /etc/init/{{ process }}s.conf

{{ process }}-service:
    file.managed:
        - name: /etc/init/{{ process }}.conf
        - source: salt://search/config/etc-init-search-{{ process }}.conf
        - template: jinja
        - require:
            - aws-credentials-deploy-user
            - search-cache-clean
        - require_in:
            - search-processes-task
{% endfor %}

search-processes-task:
    file.managed:
        - name: /etc/init/search-processes.conf
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}

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

# 16.04+

{% for process in pillar.elife.multiservice.services %}
{{ process }}-service:
    file.managed:
        - name: /lib/systemd/system/{{ process }}@.service
        - source: salt://search/config/lib-systemd-system-{{ process }}@.service
        - template: jinja
        - context:
            process: {{ process }}
{% endfor %}

{% endif %}
