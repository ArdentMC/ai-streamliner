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

## AWS MARKETPLACE INSTRUCTIONS
# Deploy AI Streamliner Cluster

First ensures a Kind cluster exists by executing the make cluster command, then pull the streamliner image and execute the deployment script.

## Prerequisites
- Docker installed and running
- Kind cluster tooling available
- Kubectl and Kustomize
- Helm

```
make cluster

docker run --rm -v $(pwd)/output:/output 905418165254.dkr.ecr.us-east-1.amazonaws.com/aistreamliner:latest && cd output && ./deploy-ai-streamliner.sh
```

## Windows Users (WSL)

1. Follow the same steps as Linux
2. If you encounter permission errors during the build process, run:
   ```bash
   sudo chmod -R 755 custom-centraldashboard/ kubeflow-source/
   sudo chown -R $(whoami):$(whoami) custom-centraldashboard/ kubeflow-source/
3. Then retry deployment command from the output directory: ./deploy-ai-streamliner.sh

## Publishing a new release of AI-Streamliner
To build and publish a new multi-arch (linux/amd64, linux/arm64) release of AI Streamliner, use the dedicated release.mk file. It logs in to ECR, builds per-arch images, creates a clean multi-arch index tag, and can verify and output digests.

1) Login to ECR
```bash
make -f release.mk image-login REGISTRY_ID=709825985650 REGION=us-east-1
```

2) Build and publish version 1.0.3
```bash
make -f release.mk image-release VERSION=1.0.3 REGISTRY_ID=709825985650 REPO=ardent-mc/aistreamliner
```
This publishes:
- Multi-arch tag: 709825985650.dkr.ecr.us-east-1.amazonaws.com/ardent-mc/aistreamliner:1.0.3
- Per-arch tags: ...:1.0.3-amd64 and ...:1.0.3-arm64

3) Verify index contents
```bash
make -f release.mk image-verify VERSION=1.0.3 REGISTRY_ID=709825985650 REPO=ardent-mc/aistreamliner
```

4) Output per-arch digests (for scanners/Marketplace)
```bash
make -f release.mk image-digests VERSION=1.0.3 REGISTRY_ID=709825985650 REPO=ardent-mc/aistreamliner
```

Note: Security scanners should scan the per-arch image digests (amd64 and arm64). The multi-arch tag is an OCI index that points to those images and is used for distribution.
