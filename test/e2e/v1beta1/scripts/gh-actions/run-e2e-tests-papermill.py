import argparse
import fileinput
import logging
import sys

import papermill as pm
import os
import shutil


#TODO: Later to run as part of git job
def prepare_file(source_path, destination_path):

    if not os.path.exists(destination_path):
        try:
            shutil.copy(source_path, destination_path)
            print(f"Copied file from {source_path} to {destination_path}")
        except Exception as e:
            print(f"Failed to copy file: {e}")
    else:
        print(f"File already exists at {destination_path}")



def run_notebook(experiment_path, namespace, verbose):

    logging.debug("In run notebook")

    output_notebook = f"{os.path.splitext(experiment_path)[0]}_output.ipynb"

    logging.info(f"Running the notebook: {experiment_path}")

    try:
        # Execute the notebook using papermill
        pm.execute_notebook(
            experiment_path,
            output_notebook,
            log_output=verbose,
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
        "--namespace", type=str, required=False, help="Namespace for the Katib E2E test",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Verbose output for the Katib E2E test",
    )
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)


    #TODO: Later to be implement as part of git job
    # source_path_api_pb2 = "pkg/apis/manager/v1beta1/python/api_pb2.py"
    # destination_path_katib_api_pb2 = "sdk/python/v1beta1/kubeflow/katib/katib_api_pb2.py"
    # source_path_api_pb2_grpc = "pkg/apis/manager/v1beta1/python/api_pb2_grpc.py"
    # destination_path_api_pb2_grpc = "sdk/python/v1beta1/kubeflow/katib/katib_api_pb2_grpc.py"
    # prepare_file(source_path_api_pb2, destination_path_katib_api_pb2)
    # prepare_file(source_path_api_pb2_grpc, destination_path_api_pb2_grpc)
    #
    # def replace_imports(filepath, original_import, new_import):
    #     with fileinput.FileInput(filepath, inplace=True, backup='.bak') as file:
    #         for line in file:
    #             print(line.replace(original_import, new_import), end='')
    #
    # # Path to the file that needs the import change
    # file_to_modify = "sdk/python/v1beta1/kubeflow/katib/katib_api_pb2_grpc.py"
    #
    # # Replace the original import with the new one
    # replace_imports(file_to_modify, 'import api_pb2 as api__pb2', 'from . import katib_api_pb2 as api__pb2')

    # Run the notebook and check its output
    success = run_notebook(args.experiment_path, args.namespace, args.verbose)


    logging.debug(f"arguments are: {args.experiment_path, args.namespace, args.verbose}")

    logging.info("---------------------------------------------------------------")
    logging.info("---------------------------------------------------------------")
    logging.info(f"Start E2E test for the Katib Experiment: {args.experiment_path}")

    if success:
        logging.info("E2E test passed.")
    else:
        logging.info("E2E test failed.")


if __name__ == "__main__":
    main()
