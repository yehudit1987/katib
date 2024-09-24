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

# Set the appropriate namespace for deployment
KUSTOMIZE_DIR="common/kubeflow-namespace/base"
kubectl apply -k $KUSTOMIZE_DIR

# Deploy the required components in the following order
kubectl apply -k common/cert-manager/cert-manager/base
kubectl apply -k common/istio-1-9/istio-crds/base
kubectl apply -k common/istio-1-9/istio-install/base
kubectl apply -k common/dex/overlays/istio
kubectl apply -k common/oidc-authservice/base
kubectl apply -k common/kubeflow-roles/base

# Deploy individual Kubeflow components
kubectl apply -k apps/pipeline/upstream/env/platform-agnostic-multi-user
kubectl apply -k apps/katib/upstream/installs/katib-standalone
kubectl apply -k apps/jupyter/notebook-controller/upstream/overlays/kubeflow
kubectl apply -k apps/training-operator/upstream/overlays/kubeflow
kubectl apply -k apps/volumes-web-app/upstream/overlays/kubeflow

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
