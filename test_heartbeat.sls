test_heartbeat:
  cmd.run:
    - name: |
        for i in {1..10}; do echo "Heartbeat $i"; sleep 1; done
    - output_loglevel: info
