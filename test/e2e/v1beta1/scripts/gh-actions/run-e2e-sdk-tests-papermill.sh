#!/bin/bash

# Get the input experiments string
EXPERIMENTS="$1"

# Split the string into an array
IFS=',' read -r -a EXP_ARRAY <<< "$EXPERIMENTS"

# Check available Jupyter kernels
echo "Available Jupyter kernels:"
jupyter kernelspec list

# Loop through each experiment and run the Python script
for EXP in "${EXP_ARRAY[@]}"; do
  echo "Running experiment: $EXP"

  # Call the Python script for each experiment
  python3 ./test/e2e/v1beta1/scripts/gh-actions/run-e2e-sdk-tests-papermill.py --experiment-path "examples/v1beta1/sdk/$EXP" --verbose || {
      echo "Python script failed for experiment: $EXP"
      exit 1
  }
done