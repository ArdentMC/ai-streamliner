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
   make streamliner
   ```

2. If problems arise, uninstall and retry the `make deploy-streamliner` command.
   ```bash
   make destroy-streamliner
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


### Useful Resources:
- mlflow
   - https://www.atlantic.net/gpu-server-hosting/how-to-deploy-mlflow-on-the-kubernetes-cluster/
- aimstack
   - https://docs.aimhub.io/quick-start/installation/k8s-helm-chart
   - https://github.com/geekbass/aimstack/tree/main
   - https://hub.docker.com/r/aimstack/aim
- lakefs
   - https://artifacthub.io/packages/helm/lakefs/lakefs