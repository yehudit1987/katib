#!/usr/bin/env bash

# Create a Kubernetes cluster using Kind

set -o errexit
set -o pipefail
set -o nounset

CLUSTER_NAME="kubeflow-cluster"
RETRY_COUNT=5        # Number of retries
RETRY_DELAY=10       # Delay in seconds between retries

echo "Creating Kind cluster: $CLUSTER_NAME"

# Create a cluster configuration file
cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
EOF

echo "Kind cluster '$CLUSTER_NAME' created successfully."

# Function to check node status with retries
check_nodes() {
  local attempt=1

  while (( attempt <= RETRY_COUNT )); do
    echo "Checking node status (attempt $attempt of $RETRY_COUNT)..."

    # Get node status
    kubectl get nodes

    # Check if any nodes are not ready
    if ! kubectl get nodes | grep -q "NotReady"; then
      echo "All nodes are ready."
      return 0
    fi

    echo "Warning: One or more nodes are not ready. Retrying in $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
    ((attempt++))
  done

  echo "Error: Nodes are still not ready after $RETRY_COUNT attempts."
  kubectl describe nodes
  exit 1
}

# Display cluster information
kubectl cluster-info

# Check the status of the nodes
check_nodes

echo "Cluster setup complete."
