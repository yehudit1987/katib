import argparse
import logging
import sys

import papermill as pm
import os

def run_notebook(experiment_path, verbose):

    logging.debug("In run notebook")

    output_notebook = f"{os.path.splitext(experiment_path)[0]}_output.ipynb"

    logging.info(f"Running the notebook: {experiment_path}")

    try:
        # Execute the notebook using papermill
        pm.execute_notebook(
            experiment_path,
            output_notebook,
            log_output=verbose,
            kernel_name="python3"
        )
        logging.info(f"Notebook executed successfully. Output saved to {output_notebook}.")
        return True
    except pm.exceptions.PapermillExecutionError as e:
        logging.info(f"Notebook execution failed: {str(e)}")
        return False
    except Exception as e:
        logging.info(f"An unexpected error occurred: {str(e)}")
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--experiment-path",
        type=str,
        required=True,
        help="Path to the Katib Experiment (Jupyter notebook).",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Verbose output for the Katib E2E test",
    )
    args = parser.parse_args()

    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[logging.StreamHandler(sys.stdout)]
    )

    # Log the current environment and paths
    logging.info("Current environment:")
    logging.info(os.environ)

    # Check available Jupyter kernels
    logging.info("Available Jupyter kernels:")
    os.system("jupyter kernelspec list")

    # Run the notebook and check its output
    success = run_notebook(args.experiment_path, args.verbose)

    logging.info("---------------------------------------------------------------")
    logging.info("---------------------------------------------------------------")
    logging.info(f"Start E2E test for the Katib Experiment: {args.experiment_path}")

    if success:
        logging.info("E2E test passed.")
        exit(0)
    else:
        logging.info("E2E test failed.")
        exit(1)


if __name__ == "__main__":
    main()
