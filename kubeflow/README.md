# Instructions
This script automates the deployment of Kubeflow on an AWS Kubernetes cluster with dex on EKS for authentication.

# Prerequisites:
   - A running Kubernetes cluster with sufficient resources.
   - kustomize and kubectl installed and configured to interact with the cluster.
   - the oidc ARN of the cluster: `https://oidc.eks.AWS_REGION.amazonaws.com/id/CLUSTER_ID`

# Usage:
```bash
chmod +x deploy-kubeflow.sh
./deploy-kubeflow.sh $OIDC_ARN
```
# Description:
The script clones the `kubeflow/manifests` repo and edits the `kustomize.yaml` files to
install the necessary resources and configurations to deploy Kubeflow. It ensures that 
all required components are installed and configured properly in the specified namespace.
An example ingress template is also provided if the deployment will be exposed.

# Exposing the dashboard:
After entering the ARN of an SSL certificate, which may appear similar to this syntax:
`arn:aws:acm:AWS_REGION:AWS_ACCOUNT:certificate/CERTIFICATE_ID`
Apply the configuration:
```bash
kubectl apply -f ingress.yaml
```
If you use the AWS Route 53 service, configure the endpoint there after retrieving the ingress address returned from this command:
```bash
kubectl get ingresses -n istio-system
```

# Notes:
   - Ensure that you have the necessary permissions to create resources in the specified namespace.
   - The script may require elevated privileges depending on your cluster setup.