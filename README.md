# AI-Streamliner

## Prerequisites
Before getting started, ensure you have the following prerequisites installed:

kind
docker
kubectl
kustomize

## Standard Deployment Process
1. To deploy all AI-Streamliner resources in a single command:
   ```bash
   make all
   ```

2. If problems arise, uninstall and retry the `make deploy-all` command.
   ```bash
   make destroy-all
   ```

## Stand-alone Tool Deployment
1. You can install a stand-alone tool using the following template:
   ```bash
   make deploy-<TOOL>
   ```
The available stand-alone deployments are kubeflow, mlflow, lakefs, and aim.

2. You can uninstall retry any installation as well.
   ```bash
   make tear-down-<TOOL>
   ```

## Timeline
Stay tuned, as we will be releasing easy installation scripts for the following tools:
- minio
- keycloak
