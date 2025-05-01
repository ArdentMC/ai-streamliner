# AI-Streamliner

## Standard Deployment Process
1. To deploy all AI-Streamliner resources in a single command:
   ```bash
   make deploy-all
   ```

2. If problems arise, uninstall and retry the `make deploy-all` command.
   ```bash
   make tear-down-all
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


* Key Considerations:
   - In order for the cicd cluster to deploy to the apps cluster, the apps cluster's "additional" security group must be modified to add the cicd cluster's node security group as an inbound rule.
