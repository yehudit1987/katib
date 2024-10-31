#!/usr/bin/env bash

# Exit on any error
set -o errexit
set -o pipefail
set -o nounset

# Install dependencies: Docker, kind, and kustomize, if not already installed
echo "Setting up dependencies..."
if ! command -v docker &>/dev/null; then
    echo "Docker is required but not found. Please ensure Docker is set up in your GitHub Action."
    exit 1
fi

if ! command -v kind &>/dev/null; then
    echo "Installing kind..."
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

if ! command -v kustomize &>/dev/null; then
    echo "Installing kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    chmod +x ./kustomize
    sudo mv ./kustomize /usr/local/bin/kustomize
fi

# Create kind cluster for Kubeflow
echo "Creating kind cluster for Kubeflow..."
cat <<EOF | kind create cluster --name=kubeflow --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        "service-account-issuer": "kubernetes.default.svc"
        "service-account-signing-key-file": "/etc/kubernetes/pki/sa.key"
EOF

# Export kubeconfig for use in kubectl commands
export KUBECONFIG="$(kind get kubeconfig-path --name=kubeflow)"

# Set up Docker registry secret for image pulling (ensure Docker is logged in beforehand)
echo "Setting up Docker registry credentials..."
if [[ ! -f "${HOME}/.docker/config.json" ]]; then
    echo "Docker config.json not found! Please log in to Docker first."
    exit 1
fi

kubectl create secret generic regcred \
    --from-file=.dockerconfigjson="${HOME}/.docker/config.json" \
    --type=kubernetes.io/dockerconfigjson

# Download Kubeflow manifests
echo "Downloading Kubeflow manifests..."
git clone --depth=1 https://github.com/kubeflow/manifests.git kubeflow-manifests

# Deploy Kubeflow components
echo "Deploying Kubeflow components..."
while ! kustomize build kubeflow-manifests/example | kubectl apply -f -; do
    echo "Retrying to apply resources"
    sleep 60
done

# Verify deployment
echo "Verifying Kubeflow deployment..."

# Check the status of all pods in the 'kubeflow' namespace
kubectl -n kubeflow get pods
sleep 60

# Validate Katib components are ready
#echo "Validating Katib components..."
#KATIB_READY=$(kubectl -n kubeflow get pods -l "katib.kubeflow.org/component in (controller, db-manager)" -o json | jq '[.items[] | select(all(.status.containerStatuses[].ready == true))] | length')
#KATIB_TOTAL=$(kubectl -n kubeflow get pods -l "katib.kubeflow.org/component in (controller, db-manager)" --no-headers | wc -l)
#echo "KATIB_READY = $KATIB_READY KATIB_TOTAL = $KATIB_TOTAL"
#if [ "$KATIB_READY" -eq "$KATIB_TOTAL" ]; then
#    echo "All required Katib components are ready."
#else
#    echo "Some required Katib components are not ready!"
#    exit 1
#fi

# Validate Pipelines components are ready
#echo "Validating Pipelines components..."
#PIPELINES_READY=$(kubectl -n kubeflow get pods -l "control-plane=controller" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -c True)
#PIPELINES_TOTAL=$(kubectl -n kubeflow get pods -l "control-plane=controller" --no-headers | wc -l)
#
#if [ "$PIPELINES_READY" -eq "$PIPELINES_TOTAL" ]; then
#    echo "All required Pipelines components are ready."
#else
#    echo "Some required Pipelines components are not ready!"
#    exit 1
#fi

echo "Kubeflow installation completed successfully."
