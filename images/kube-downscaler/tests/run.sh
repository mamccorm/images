#!/usr/bin/env bash

set -o errexit -o nounset -o errtrace -o pipefail -x

function cleanup() {
	# Print debug logs and status
	kubectl get pods
	kubectl describe pods

	# Seeing intermittent failures if we don't wait for a bit here
	# The `rollout status`` below should wait for terminated pods to be removed
	# However, we still occasionally see a terminating pod which fails when checking logs
	sleep 10
	kubectl logs --selector application=kube-downscaler
}

trap cleanup EXIT

# Deploy the kube-downscaler yaml
kubectl apply -f https://codeberg.org/hjacobs/kube-downscaler/raw/tag/23.2.0/deploy/config.yaml
kubectl apply -f https://codeberg.org/hjacobs/kube-downscaler/raw/tag/23.2.0/deploy/rbac.yaml
kubectl apply -f https://codeberg.org/hjacobs/kube-downscaler/raw/tag/23.2.0/deploy/deployment.yaml

# The pod can take a few seconds to appear after the deployment and the replicaset are all created and reconcile
sleep 10

# Wait for the default kube-downscaler to be healthy
kubectl wait --for=condition=ready pod --selector application=kube-downscaler --timeout=120s

# Swap out the image
kubectl set image deployment/kube-downscaler downscaler="${IMAGE_NAME}"

# Wait for the replicaset to be ready and old pods to terminated
kubectl rollout status deployment/kube-downscaler --timeout=120s

# Check the kube-downscaler pods are deployed and healthy
kubectl wait --for=condition=ready pod --selector application=kube-downscaler --timeout=120s

# Additional test to validate service is running, by querying logs
expected_log="INFO: Downscaler v[0-9]+\.[0-9]+\.[0-9]+ started"
retry_count=0
max_retries=3
delay=10

while (( retry_count < max_retries )); do
  if kubectl logs --selector application=kube-downscaler | grep -qE "$expected_log"; then
    echo "INFO: kube-downscaler is running, found the following log line: $expected_log"
    break
  else
    echo "ERROR: kube-downscaler - expected startup log line: $expected_log was NOT FOUND."
    ((retry_count++))
    sleep $delay
  fi
done

if (( retry_count == max_retries )); then
  echo "Error: Expected log string not found after $max_retries retries!"
  exit 1
fi
