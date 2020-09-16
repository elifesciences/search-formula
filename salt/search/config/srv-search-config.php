<?php

use Monolog\Logger;

return [
    'debug' => {% if pillar.search.debug %}true{% else %}false{% endif %},
    'validate' => {% if pillar.search.validate %}true{% else %}false{% endif %},
    'ttl' => {{ pillar.search.ttl }},
    'elastic_servers' => ['{{ pillar.search.elasticsearch.servers }}'],
    'elastic_logging' => {% if pillar.search.elasticsearch.logging %}true{% else %}false{% endif %},
    'elastic_force_sync' => {% if pillar.search.elasticsearch.force_sync %}true{% else %}false{% endif %},
    'gearman_servers' => ['{{ pillar.search.gearman.servers }}'],
    'api_url' => '{{ pillar.search.api.url }}',
    'api_requests_batch' => {{ pillar.search.api.requests_batch }},
    'rate_limit_minimum_page' => {{ pillar.search.rate_limit_minimum_page }},
    'aws' => [
        {% if salt['elife.only_on_aws']() %}
        'queue_name' => 'search--{{ salt['elife.cfg']('project.instance_id') }}',
        {% else %}
        'queue_name' => 'search--dev',
        {% endif %}
        'credential_file' => true,
        'region' => 'us-east-1',
        {% if pillar.search.aws.endpoint %}
        'endpoint' => '{{ pillar.search.aws.endpoint }}',
        {% endif %}
    ],
    'era_articles' => [
        {% for id, values in pillar.search.era_articles.items() %}
        '{{ id }}' => [
            'date' => '{{ values.date }}',
            'display' => '{{ values.display }}',
            'download' => '{{ values.download }}',
        ],
        {% endfor %}
    ],
    'rds_articles' => [
        {% for id, values in pillar.search.rds_articles.items() %}
        '{{ id }}' => [
            'date' => '{{ values.date }}',
            'display' => '{{ values.display }}',
            'download' => '{{ values.download }}',
        ],
        {% endfor %}
    ],
];
