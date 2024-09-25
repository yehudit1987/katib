#!/bin/bash

# Define variables
KUSTOMIZATION_PATH="manifests/v1beta1/installs/katib-standalone/"
KATIB_NAMESPACE="kubeflow"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl not found. Please install kubectl to use this script."
    exit 1
fi

echo "Creating Katib namespace..."
kubectl create namespace $KATIB_NAMESPACE || echo "Namespace $KATIB_NAMESPACE already exists"

# Apply Katib manifests using kustomize
echo "Applying Katib manifests..."
kubectl apply -k $KUSTOMIZATION_PATH


echo "Waiting for Katib pods to be ready..."
TIMEOUT=180s

# Wait for all pods in the kubeflow namespace to be in the Ready state
PODS_READY=$(kubectl wait --for=condition=ready --timeout=$TIMEOUT pod --all -n kubeflow)

# Check if the command was successful
if [ $? -ne 0 ]; then
  echo "Some pods did not reach the Ready state within the timeout. Checking events and logs..."

  # Loop over each deployment that timed out and print logs and events
  DEPLOYMENTS=$(kubectl get deployments -n kubeflow --no-headers -o custom-columns=":metadata.name")

  for DEPLOYMENT in $DEPLOYMENTS; do
    echo "Checking deployment: $DEPLOYMENT"

    # Get the pods for the current deployment
    PODS=$(kubectl get pods -n kubeflow -l app=$DEPLOYMENT -o jsonpath='{.items[*].metadata.name}')

    for POD in $PODS; do
      echo "Events for pod: $POD"
      kubectl describe pod $POD -n kubeflow | grep -A 10 "Events"

      echo "Logs for pod: $POD"
      kubectl logs $POD -n kubeflow
    done
  done
  exit 1

else
  echo "All Katib pods are ready!"
fi

