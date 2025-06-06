import argparse
import os

import pandas as pd

import mlflow
import mlflow.data

parser = argparse.ArgumentParser()
parser.add_argument("--data_file", type=str, required=True)
parser.add_argument("--lakefs_commit", type=str, required=False)
parser.add_argument("--lakefs_commit_url", type=str, required=False)
args = parser.parse_args()

df = pd.read_csv(args.data_file)
dataset = mlflow.data.from_pandas(
    df,
    source=args.lakefs_commit_url or args.data_file,
    name=os.path.basename(args.data_file),
)

with mlflow.start_run():
    mlflow.log_input(dataset, context="training")
    mlflow.log_artifact(args.data_file, artifact_path="datasets")
