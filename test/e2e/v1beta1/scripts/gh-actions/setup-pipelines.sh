#!/usr/bin/env bash

# This shell script is used to setup Kubeflow Pipelines deployment.
set -o errexit
set -o pipefail
set -o nounset
cd "$(dirname "$0")"

KFP_VERSION="v1.8.12"
NAMESPACE="kubeflow"
DEPLOYMENT_NAME="kubeflow-pipelines"

echo "Start to install Kubeflow Pipelines"

# Declare the Kustomization file to use for KFP
KUSTOMIZATION_FILE="../../../../../manifests/v1beta1/installs/kubeflow-pipelines/kustomization.yaml"

# Deploy Kubeflow Pipelines
kubectl apply -k "$KUSTOMIZATION_FILE"

# Wait until all KFP components are running
TIMEOUT=120s
kubectl wait --for=condition=ContainersReady=True --timeout=${TIMEOUT} -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n $NAMESPACE pod ||
  (kubectl get pods -n $NAMESPACE && kubectl describe pods -n $NAMESPACE && exit 1)

echo "All Kubeflow Pipelines components are running."
echo "Kubeflow Pipelines deployments:"
kubectl -n $NAMESPACE get deploy
echo "Kubeflow Pipelines services:"
kubectl -n $NAMESPACE get svc
echo "Kubeflow Pipelines pods:"
kubectl -n $NAMESPACE get pod

# Additional health check for KFP
kubectl get healthz -n $NAMESPACE || echo "KFP health check failed."

exit 0
