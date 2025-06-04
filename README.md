# AI-Streamliner

## Prerequisites
Before getting started, ensure you have the following prerequisites installed:

- kind - https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager
- docker - https://docs.docker.com/desktop/
- kubectl - https://docs.docker.com/desktop/
- kustomize - https://kubectl.docs.kubernetes.io/installation/kustomize/
- helm - https://helm.sh/docs/intro/install/

## Suggested tools
These tools may help manage the cluster and monitor progress during install:

- k9s - https://k9scli.io/topics/install/

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
1. To access all tools at once:
   ```bash
   make access
   ```
   This will open the dashboard at http://localhost:8080. Sign in with user@example.com/12341234

2. You can access individual tools using the following template:
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

### FYI:
When you create the kind cluster it sets the env var KUBECONFIG to the temporary kind config. If you find yourself missing your previous kubernetes contexts then use the command `unset KUBECONFIG` to use the default config file typically found here: ~/.kube/config. And if you need to use the kind context again use the command `export KUBECONFIG=/tmp/kubeflow-config;`.