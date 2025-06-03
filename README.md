# AI-Streamliner

## Prerequisites
Before getting started, ensure you have the following prerequisites installed:

kind
docker
kubectl
kustomize
helm

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
   make <TOOL>
   ```
The available stand-alone deployments are kubeflow, mlflow, lakefs, and aim.

2. You can uninstall retry any installation as well.
   ```bash
   make delete-<TOOL>
   ```

## Tool access
1. You can access a tool using the following template:
   ```bash
   make access-<TOOL>
   ```
The available stand-alone deployments are kubeflow, mlflow, lakefs, and aim.

## Timeline
Stay tuned, as we will be releasing easy installation scripts for the following tools:
- minio
- keycloak
