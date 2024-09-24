#!/usr/bin/env bash

# Create a Kubernetes cluster using Kind

set -o errexit
set -o pipefail
set -o nounset

CLUSTER_NAME="kubeflow-cluster"

echo "Creating Kind cluster: $CLUSTER_NAME"

# Create a cluster configuration file
cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
EOF

echo "Kind cluster '$CLUSTER_NAME' created successfully."

# Display cluster information
kubectl cluster-info
