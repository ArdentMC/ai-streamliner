# AI-Streamliner
This project automates deployment of Kubeflow, MLflow, Aim, and LakeFS into a unified webapp deployed in kind.

## Prerequisites
Before getting started, ensure you have the following prerequisites installed:

- kind - https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager
   - check `kind version`
- docker - https://docs.docker.com/desktop/
   - check `docker version`
- kubectl - https://kubernetes.io/docs/tasks/tools/#kubectl
   - check `kubectl version`
- kustomize - https://kubectl.docs.kubernetes.io/installation/kustomize/
   - check `kustomize version`
- helm - https://helm.sh/docs/intro/install/
   - check `helm version`

## Docker configuration
Make sure docker is configured for 16 GB of ram and 8 CPU cores.

## Suggested tools
These tools may help manage the cluster and monitor progress during install:

- k9s - https://k9scli.io/topics/install/
   - check `k9s version`

## Script Organization
The project contains several scripts:

- **.\Make** - Primary Windows-native batch script for deploying and managing AI-Streamliner
- **Makefile** - Original macOS/Linux/WSL script for deploying and managing AI-Streamliner

## Standard Deployment Process
### For Windows Users
1. To check if all prerequisite tools are installed:
   ```cmd
   .\Make check
   ```
2. To deploy all AI-Streamliner resources in a single command:
   ```cmd
   .\Make streamliner
   ```
3. Ignore any errors or outputs in the terminal. If installation doesn't complete in 15 minutes, try again. The installation will either succeed or fail no intervention is necessary while installing.
4. To monitor deployment in a new terminal:
   ```powershell
   $env:KUBECONFIG="$env:TEMP\kubeflow-config"
   kubectl config use-context kind-kubeflow
   k9s
   ```
5. To access all AI-Streamliner tools:
   ```cmd
   .\Make access
   ```
   > **Note:** The access command automatically waits for all pods to be ready before starting port-forwarding. If some components are still in the ContainerCreating state, the script will wait until they are running.

### For macOS/Linux/WSL Users
1. To check if all prerequisite tools are installed:
   ```bash
   make check-dependencies
   ```
2. To deploy all AI-Streamliner resources in a single command:
   ```bash
   make streamliner
   ```
3. Ignore any errors or outputs in the terminal. If installation doesn't complete in 15 minutes, try again. The installation will either succeed or fail no intervention is necessary while installing.

4. To monitor deployment in a new terminal (make sure to set the context in other terminals before running make commands ):
   ```bash
   export KUBECONFIG=/tmp/kubeflow-config;
   kubectl config use-context kind-kubeflow
   k9s
   ```
5. To access all AI-Streamliner tools:
   ```bash
   make access
   ```
   > **Note:** The access command automatically waits for all pods to be ready before starting port-forwarding. If some components are still in the ContainerCreating state, the script will wait until they are running.

## Stand-alone Tool Deployment

### For macOS/Linux/WSL Users
1. You can install a stand-alone tool using the following template:
   ```bash
   make <TOOL>
   ```
The available stand-alone deployments are kubeflow, mlflow, lakefs, and aim.

2. You can uninstall retry any installation as well.
   ```bash
   make delete-<TOOL>
   ```

### For Windows Users
1. You can install a stand-alone tool using the native Windows Makefile:
   ```cmd
   .\Make kubeflow
   .\Make mlflow
   .\Make aim
   .\Make lakefs
   ```

2. You can uninstall any installation:
   ```cmd
   .\Make delete-mlflow
   .\Make delete-aim
   .\Make delete-lakefs
   ```

3. To destroy the cluster:
   ```cmd
   .\Make destroy-cluster
   ```

## Tool access

### For macOS/Linux/WSL Users
1. To access AI Streamliner:
   ```bash
   make access
   ```
   This will open the dashboard at http://localhost:8080. Sign in with user@example.com/12341234

2. You can access individual tools using the following template:
   ```bash
   make access-<TOOL>
   ```

### For Windows Users
1. To access AI Streamliner:
   ```cmd
   .\Make access
   ```

2. You can access individual tools using:
   ```cmd
   .\Make access-kubeflow
   .\Make access-mlflow
   .\Make access-aim
   .\Make access-lakefs
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

### Troubleshooting
- Kubeflow Authentication Issues
   - If you encounter errors like "Jwks doesn't have key to match kid or alg from Jwt" when accessing Kubeflow, this is likely related to the `oauth2_proxy_kubeflow` cookie:

      - **Clear Browser Cookies**: 
         - Open your browser developer tools (F12 or right-click -> Inspect)
         - Go to the Application/Storage tab
         - Find and delete cookies for localhost, particularly `oauth2_proxy_kubeflow`
         - Refresh the page
- When you create the kind cluster it sets the env var KUBECONFIG to the temporary kind config. If you find yourself missing your previous kubernetes contexts then use the command `unset KUBECONFIG` to use the default config file typically found here: ~/.kube/config. And if you need to use the kind context again use the command `export KUBECONFIG=/tmp/kubeflow-config;`.
- the /tmp directory might clean up the config file after some time. Use `kind get kubeconfig --name kubeflow > /tmp/kubeflow-config` to recreate it. Bug fix wanted (good first issue).
- If you find want to troubleshoot a faulty installation step look at the makefile to identify which command is failing. Connect to the cluster and attempt to run the command manually. If it succeeds, run the make streamliner command again to continue with the full installation.