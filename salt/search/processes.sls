search-gearman-workers-start:
    cmd.run:
        - name: start search-gearman-workers
        - require:
            - search-gearman-workers-task
