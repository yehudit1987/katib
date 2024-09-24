#!/usr/bin/env bash

# Copyright 2024
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is used to setup a full Kubeflow deployment.
set -o errexit
set -o pipefail
set -o nounset
cd "$(dirname "$0")"

KUBEFLOW_VERSION="v1.9.0"
KUBEFLOW_MANIFESTS_REPO="https://github.com/kubeflow/manifests"
KUSTOMIZE_VERSION="v4.5.7"

# Install kubectl if it's not already installed
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

# Install kustomize if it's not already installed
if ! command -v kustomize &> /dev/null; then
  echo "Installing kustomize..."
  curl -s "https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest" |
    grep "browser_download_url.*linux_amd64.tar.gz" |
    cut -d : -f 2,3 |
    tr -d \" |
    wget -qi -
  tar -xzf kustomize_v*linux_amd64.tar.gz
  sudo mv kustomize /usr/local/bin/
  rm kustomize_v*linux_amd64.tar.gz
fi

echo "Start to install Kubeflow"

# Clone the Kubeflow manifests repository
if [ ! -d "kubeflow-manifests" ]; then
  git clone "$KUBEFLOW_MANIFESTS_REPO" kubeflow-manifests
fi

cd kubeflow-manifests

# Checkout the specific Kubeflow version
git checkout $KUBEFLOW_VERSION

# Function to check if the CRD is established
apply_component() {
    local component_path="$1"
    local max_retries=3
    local delay=30

    echo "Applying component from path: $component_path"

    for ((i=0; i<max_retries; i++)); do
        # Attempt to apply the component
        if kustomize build "$component_path" | kubectl apply -f -; then
            echo "Successfully applied component: $component_path"
            return 0
        else
            echo "Failed to apply component: $component_path. Attempt $((i+1))/$max_retries."
            sleep "$delay"
        fi
    done

    echo "Exceeded maximum retries for component: $component_path"
    return 1
}

# Apply essential components
apply_component "common/kubeflow-namespace/base"
apply_component "common/kubeflow-roles/base"
apply_component "common/cert-manager/cert-manager/base"
apply_component "common/istio-1-22/istio-crds/base"
apply_component "common/istio-1-22/istio-namespace/base"
apply_component "common/istio-1-22/istio-install/base"
apply_component "common/dex/overlays/istio"
apply_component "apps/pipeline/upstream/env/platform-agnostic-multi-user"
apply_component "apps/katib/upstream/installs/katib-standalone"

echo "Kubeflow deployments:"
kubectl -n kubeflow get deploy

# Describe each deployment in the kubeflow namespace
for deployment in $(kubectl -n kubeflow get deploy -o jsonpath='{.items[*].metadata.name}'); do
    echo "-------------------------------------------------------------------------------------"
    echo "Describing deployment: $deployment"
    kubectl -n kubeflow describe deployment $deployment

    # Fetch the associated replica sets for more details (like SCC issues)
    for replicaset in $(kubectl -n kubeflow get rs -l "app.kubernetes.io/name=$deployment" -o jsonpath='{.items[*].metadata.name}'); do
        echo "Describing replica set: $replicaset"
        kubectl -n kubeflow describe rs $replicaset
    done

    # Fetch pods managed by this deployment to check for pod-level issues
    for pod in $(kubectl -n kubeflow get pods -l "app.kubernetes.io/name=$deployment" -o jsonpath='{.items[*].metadata.name}'); do
        echo "Describing pod: $pod"
        kubectl -n kubeflow describe pod $pod

        # Capture logs of the pod if it's not running properly
        echo "Fetching logs for pod: $pod"
        kubectl -n kubeflow logs $pod
    done
    echo "-------------------------------------------------------------------------------------"
done

# Wait for all pods to be running
echo "Waiting for Kubeflow components to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=600s -n kubeflow

# Output the status of the components
echo "Kubeflow deployments:"
kubectl -n kubeflow get deploy

echo "Kubeflow services:"
kubectl -n kubeflow get svc

echo "Kubeflow pods:"
kubectl -n kubeflow get pod

echo "Kubeflow has been successfully deployed."

exit 0
