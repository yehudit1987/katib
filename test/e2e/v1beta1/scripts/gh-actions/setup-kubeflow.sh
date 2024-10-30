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

# Check Kubernetes version
required_k8s_version="1.29"
k8s_version=$(kubectl version --short | grep Server | awk '{print $3}')
if [[ "$(printf '%s\n' "$required_k8s_version" "$k8s_version" | sort -V | head -n1)" != "$required_k8s_version" ]]; then
    echo "Error: Kubernetes version must be ${required_k8s_version}+ (current: ${k8s_version})"
    exit 1
fi

# Check Kustomize version
required_kustomize_version="5.2.1"
kustomize_version=$(kustomize version | grep -oP '\d+\.\d+\.\d+')
if [[ "$(printf '%s\n' "$required_kustomize_version" "$kustomize_version" | sort -V | head -n1)" != "$required_kustomize_version" ]]; then
    echo "Error: Kustomize version must be ${required_kustomize_version}+ (current: ${kustomize_version})"
    exit 1
fi

# Check kubectl version
kubectl_version=$(kubectl version --client --short | awk '{print $3}')
if [[ "$(printf '%s\n' "$required_k8s_version" "$kubectl_version" | sort -V | head -n1)" != "$required_k8s_version" ]]; then
    echo "Error: Kubectl version must be compatible with Kubernetes version (current: ${kubectl_version})"
    exit 1
fi

# Check for default StorageClass
if ! kubectl get storageclass | grep -q 'default'; then
    echo "Error: No default StorageClass found in the cluster."
    exit 1
fi

# Create kind cluster for Kubeflow
echo "Creating kind cluster for Kubeflow..."
cat <<EOF | kind create cluster --name=kubeflow --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.31.0
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

# Validate Katib components are ready
echo "Validating Katib components..."
KATIB_READY=$(kubectl -n kubeflow get pods -l "katib.kubeflow.org/component in (controller, db-manager, ui)" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c True)
KATIB_TOTAL=$(kubectl -n kubeflow get pods -l "katib.kubeflow.org/component in (controller, db-manager, ui)" --no-headers | wc -l)

if [ "$KATIB_READY" -eq "$KATIB_TOTAL" ]; then
    echo "All Katib components are ready."
else
    echo "Some Katib components are not ready!"
    exit 1
fi

# Validate Pipelines components are ready
echo "Validating Pipelines components..."
PIPELINES_READY=$(kubectl -n kubeflow get pods -l "control-plane=controller" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c True)
PIPELINES_TOTAL=$(kubectl -n kubeflow get pods -l "control-plane=controller" --no-headers | wc -l)

if [ "$PIPELINES_READY" -eq "$PIPELINES_TOTAL" ]; then
    echo "All Pipelines components are ready."
else
    echo "Some Pipelines components are not ready!"
    exit 1
fi

echo "Kubeflow installation completed successfully."
