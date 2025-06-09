# AI-Streamliner

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
Make sure your docker configuration has 16 GB of ram and 8 CPU cores.

### Windows-native Deployment
```cmd
.\Make streamliner    # Deploy all components
.\Make kubeflow       # Deploy only Kubeflow
.\Make mlflow         # Deploy only MLflow 
.\Make check          # Check requirements
```

### Troubleshooting Kubeflow Authentication Issues
If you encounter errors like "Jwks doesn't have key to match kid or alg from Jwt" when accessing Kubeflow, this is likely related to the `oauth2_proxy_kubeflow` cookie:

1. **Clear Browser Cookies**: 
   - Open your browser developer tools (F12 or right-click -> Inspect)
   - Go to the Application/Storage tab
   - Find and delete cookies for localhost, particularly `oauth2_proxy_kubeflow`
   - Refresh the page

## Suggested tools
These tools may help manage the cluster and monitor progress during install:

- k9s - https://k9scli.io/topics/install/
   - check `k9s version`

## Standard Deployment Process
### For Windows Users
1. To deploy all AI-Streamliner resources in a single command:
   ```cmd
   .\Make streamliner
   ```
2. To monitor deployment in a new terminal:
   ```powershell
   $env:KUBECONFIG="$env:TEMP\kubeflow-config"
   kubectl config use-context kind-kubeflow
   k9s
   ```
3. To access all AI-Streamliner tools:
   ```cmd
   .\Make access
   ```
   > **Note:** The access command automatically waits for all pods to be ready before starting port-forwarding. If some components are still in the ContainerCreating state, the script will wait until they are running.

### For macOS/Linux Users
1. To deploy all AI-Streamliner resources in a single command:
   ```bash
   make streamliner
   ```
2. To monitor deployment in a new terminal (make sure to set the context in other terminals before running make commands ):
   ```bash
   export KUBECONFIG=/tmp/kubeflow-config;
   kubectl config use-context kind-kubeflow
   k9s
   ```

### For Windows Users
1. **Option 1:** Using the native Windows .\Make:
   ```cmd
   .\Make check
   ```
   or
   ```cmd
   .\Make streamliner
   ```

2. To check your system requirements:
   ```cmd
   .\Make check
   ```

3. To get help on available commands:
   ```cmd
   .\Make help
   ```

## Stand-alone Tool Deployment

### For macOS/Linux Users
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

### For macOS/Linux Users
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

## Script Organization
The project contains several scripts:

- **.\Make** - Primary Windows-native batch script for deploying and managing AI-Streamliner
- **Makefile** - Original Linux/macOS script for deploying and managing AI-Streamliner

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
