#!/bin/bash
# Push N build jobs onto Kafka and watch KEDA scale build-worker pods from 0.
# Usage: ./scripts/load-test.sh 20
JOBS=${1:-10}
echo "--- Pushing $JOBS jobs to Kafka ---"
for i in $(seq 1 $JOBS); do
  kubectl exec -n launchpad deployment/upload-service -- \
    kafka-console-producer.sh \
      --bootstrap-server launchpad-kafka:9092 \
      --topic build-jobs <<< "{\"repo_id\": \"test-$i\", \"branch\": \"main\"}"
done
echo "--- Watching pod count (Ctrl+C to stop) ---"
watch -n 2 "kubectl get pods -n launchpad -l app=build-worker"
