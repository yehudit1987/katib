#!/bin/bash

# Define variables
KUSTOMIZATION_FILE="manifests/v1beta1/installs/katib-standalone/kustomization.yaml"
KATIB_NAMESPACE="kubeflow"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl not found. Please install kubectl to use this script."
    exit 1
fi

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null
then
    echo "kustomize not found. Please install kustomize to use this script."
    exit 1
fi

echo "Creating Katib namespace..."
kubectl create namespace $KATIB_NAMESPACE || echo "Namespace $KATIB_NAMESPACE already exists"

# Apply Katib manifests using kustomize
echo "Applying Katib manifests using Kustomize from $KUSTOMIZATION_FILE..."

kustomize build $KUSTOMIZATION_FILE | kubectl apply -n $KATIB_NAMESPACE -f -

# Wait for deployments to roll out
echo "Waiting for Katib pods to be ready..."

kubectl rollout status -n $KATIB_NAMESPACE deployment/katib-controller
kubectl rollout status -n $KATIB_NAMESPACE deployment/katib-db-manager
kubectl rollout status -n $KATIB_NAMESPACE deployment/katib-ui

# Confirm that all pods are running
echo "Checking the status of Katib pods..."
kubectl get pods -n $KATIB_NAMESPACE

echo "Katib deployment complete!"
