# Apps Cluster Creation Process

## Terraform Apply Instructions
1. Initialize Terraform in your project directory: `terraform init`
2. Apply Terraform `terraform apply`

# Kubeflow Deployment

## Standard Deployment Process
1. Apply Kubernetes resources with automatic retries:
   ```bash
   cd kubeflow/overlays/

   while ! kustomize build example | kubectl apply --server-side --force-conflicts -f -; do echo "Retrying to apply resources"; sleep 20; done


2. If problems arise after two loops delete the following resources and retry the apply command.
    ```bash
    kubectl delete validatingwebhookconfiguration istio-validator-istio-system
    kubectl delete mutatingwebhookconfiguration istio-sidecar-injector

* Key Considerations:
   - In order for the cicd cluster to deploy to the apps cluster, the apps cluster's "additional" security group must be modified to add the cicd cluster's node security group as an inbound rule.
