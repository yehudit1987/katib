#!/usr/bin/env bash

# Set up Kubeflow Pipelines in the Kubernetes cluster

set -o errexit
set -o pipefail
set -o nounset

# Specify the pipeline version
export PIPELINE_VERSION=2.3.0

echo "Deploying Kubeflow Pipelines version $PIPELINE_VERSION"

# Apply cluster-scoped resources
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=$PIPELINE_VERSION"
kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io

# Apply environment-specific resources
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/dev?ref=$PIPELINE_VERSION"

echo "Kubeflow Pipelines deployment initiated. This may take approximately 3 minutes to complete."

# Wait for all pipeline components to be up and running
TIMEOUT=180s
kubectl wait --for=condition=available --timeout=$TIMEOUT deployment --all -n kubeflow
echo "All Kubeflow Pipelines components are running."
