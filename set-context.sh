kubectl config use-context kind-kubeflow;
echo "Setting up Kubeflow context...";
kind get kubeconfig --name kubeflow > /tmp/kubeflow-config;
sleep 2;
export KUBECONFIG=/tmp/kubeflow-config;
echo "Restarting all kubeflow pods...";
kubectl delete pod -n kubeflow --all;
echo "=========================================================";
echo "Pods deleted."
echo "Waiting for pods to restart...";
kubectl wait --for=condition=Ready pods --all -n kubeflow --timeout=300s;
kubectl get pods -n kubeflow;
echo "=========================================================";
echo "Kubeflow context set and pods restarted successfully.";
echo "To use this context, run:"
echo "export KUBECONFIG=/tmp/kubeflow-config;";
echo "You can now access AI Streamliner's control center using the following command:";
echo "make access";