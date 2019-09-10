{% for process in pillar.elife.multiservice.services %}
{{ process }}-service:
    file.managed:
        - name: /lib/systemd/system/{{ process }}@.service
        - source: salt://search/config/lib-systemd-system-{{ process }}@.service
        - template: jinja
        - context:
            process: {{ process }}
{% endfor %}
