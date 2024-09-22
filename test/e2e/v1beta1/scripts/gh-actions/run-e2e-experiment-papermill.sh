# This shell script is used to run Katib Experiment.
# Input parameter - path to Experiment yaml.

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"

echo "Katib deployments"
kubectl -n kubeflow get deploy
echo "Katib services"
kubectl -n kubeflow get svc
echo "Katib pods"
kubectl -n kubeflow get pod
echo "Katib persistent volume claims"
kubectl get pvc -n kubeflow
echo "Available CRDs"
kubectl get crd

python run-e2e-experiment-papermill.py --namespace default \
--verbose || (kubectl get pods -n kubeflow && exit 1)