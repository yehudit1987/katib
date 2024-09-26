#!/usr/bin/env bash

# Copyright 2022 The Kubeflow Authors.
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

# This shell script is used to setup Katib deployment.

set -o errexit
set -o pipefail
set -o nounset
cd "$(dirname "$0")"

DEPLOY_KATIB_UI=${1:-false}
TUNE_API=${2:-false}
TRIAL_IMAGES=${3:-""}
EXPERIMENTS=${4:-""}

function check_minikube() {
  if minikube status >/dev/null 2>&1; then
    echo "Minikube is already running."
  else
    echo "Minikube is not running. Starting Minikube..."
    minikube start --container-runtime=docker --gpus all
  fi
}
# Function to install necessary tools
function install_tools() {
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it first."
    exit 1
  fi

  # Check if Minikube is installed
  if ! command -v minikube &> /dev/null; then
    echo "Minikube is not installed. Please install it first."
    exit 1
  fi

  # Install kubectl (if not already installed)
  if ! command -v kubectl &> /dev/null; then
    curl -LO https://dl.k8s.io/release/$(kubectl version --client | grep "Client Version:" | awk '{print $3}')/bin/linux/amd64/kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin
  fi
}

echo "Checking Minikube Kubernetes Cluster"
install_tools
check_minikube

echo "Kubernetes cluster is up and running"
kubectl version
kubectl cluster-info
kubectl get nodes

echo "Build and Load container images"
./build-load.sh "$DEPLOY_KATIB_UI" "$TUNE_API" "$TRIAL_IMAGES" "$EXPERIMENTS" 
