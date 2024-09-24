#!/bin/bash

# Define the namespace and Katib version
KATIB_NAMESPACE="kubeflow"
KATIB_VERSION="v0.15.0"  # Change this to the desired version

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl not found. Please install kubectl to use this script."
    exit 1
fi

echo "Creating Katib namespace..."
kubectl create namespace $KATIB_NAMESPACE || echo "Namespace $KATIB_NAMESPACE already exists"

# Deploy Katib manifests from the official Kubeflow repository
echo "Deploying Katib manifests for version $KATIB_VERSION..."

kubectl apply -n $KATIB_NAMESPACE -f https://raw.githubusercontent.com/kubeflow/katib/$KATIB_VERSION/manifests/v1beta1/installs/katib-install.yaml

# Check if Katib pods are running
echo "Waiting for Katib pods to be ready..."

kubectl rollout status -n $KATIB_NAMESPACE deployment/katib-controller
kubectl rollout status -n $KATIB_NAMESPACE deployment/katib-db-manager
kubectl rollout status -n $KATIB_NAMESPACE deployment/katib-ui

# Confirm that all pods are running
echo "Checking the status of Katib pods..."
kubectl get pods -n $KATIB_NAMESPACE

echo "Katib deployment complete!"
