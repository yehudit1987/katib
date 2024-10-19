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
ALGORITHMS=${5:""}

function check_minikube() {
  if minikube status >/dev/null 2>&1; then
    echo "Minikube is already running."
  else
    echo "Minikube is not running. Starting Minikube..."
    minikube start   ## --container-runtime=docker --gpus all
  fi
}
# Check Podman version
podman_version=$(podman --version | awk '{print $2}')

# Minimum required version for Minikube (replace with your desired version)
min_podman_version="4.9.0"



# Choose upgrade method based on your system
# Option 1: Using package manager (replace commands for your system)
if [ -x "$(command -v apt-get)" ]; then
  echo "Upgrading Podman using apt-get..."
  sudo apt-get update
  sudo apt-get install -y podman
elif [ -x "$(command -v dnf)" ]; then
  echo "Upgrading Podman using dnf..."
  sudo dnf upgrade podman -y
else
  echo "Package manager not found. Skipping upgrade."
fi

  # Option 2: Manual installation (uncomment and replace URLs)
  # curl -LO https://github.com/containers/podman/releases/latest/download/podman-linux-amd64  # Replace URL
  # chmod +x podman-linux-amd64
  # sudo mv podman-linux-amd64 /usr/local/bin/podman


echo "Checking Minikube Kubernetes Cluster"
check_minikube

echo "Kubernetes cluster is up and running"
kubectl version
kubectl cluster-info
kubectl get nodes

echo "Build and Load container images"
echo "algo are $ALGORITHMS"
./build-load.sh "$DEPLOY_KATIB_UI" "$TUNE_API" "$TRIAL_IMAGES" "$EXPERIMENTS" "$ALGORITHMS"
