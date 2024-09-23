#!/bin/bash

# Get the input experiments string
EXPERIMENTS="$1"

cd "./examples/v1beta1/kubeflow-pipelines/" || exit 1
echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -l

# Split the string into an array
IFS=',' read -r -a EXP_ARRAY <<< "$EXPERIMENTS"

cd "../../../test/e2e/v1beta1/scripts/gh-actions/" || exit 1
echo "Changed to tests directory: $(pwd)"
echo "Directory contents:"
ls -l

# Loop through each experiment and run the Python script
for EXP in "${EXP_ARRAY[@]}"; do
  echo "Running experiment: $EXP"

  # Call the Python script for each experiment
  python3 run-e2e-tests-papermill.py --experiment-path "$EXP" --verbose
done