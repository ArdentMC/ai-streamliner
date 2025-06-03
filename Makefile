cluster:
	kind create cluster --name=kubeflow --config=cluster.yml
	kind get kubeconfig --name kubeflow > /tmp/kubeflow-config
	export KUBECONFIG=/tmp/kubeflow-config
	docker login
	kubectl create secret generic regcred --from-file=.dockerconfigjson=$(HOME)/.docker/config.json --type=kubernetes.io/dockerconfigjson

destroy-cluster:
	kind delete cluster --name=kubeflow

kubeflow:
	cd manifests && while ! kustomize build common/cert-manager/base | kubectl apply -f -; do echo "Retrying cert-manager/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/cert-manager/kubeflow-issuer/base | kubectl apply -f -; do echo "Retrying cert-manager/kubeflow-issuer/base..."; sleep 10; done
	cd manifests && echo "Waiting for cert-manager to be ready ..."
	cd manifests && kubectl wait --for=condition=Ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
	cd manifests && kubectl wait --for=jsonpath='{.subsets[0].addresses[0].targetRef.kind}'=Pod endpoints -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
	cd manifests && echo "Installing Istio configured with external authorization..."
	cd manifests && while ! kustomize build common/istio-1-24/istio-crds/base | kubectl apply -f -; do echo "Retrying istio-crds/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/istio-1-24/istio-namespace/base | kubectl apply -f -; do echo "Retrying istio-namespace/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/istio-1-24/istio-install/overlays/oauth2-proxy | kubectl apply -f -; do echo "Retrying istio-install/overlays/oauth2-proxy..."; sleep 10; done
	cd manifests && echo "Waiting for all Istio Pods to become ready..."
	cd manifests && kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=300s
	cd manifests && echo "Installing oauth2-proxy..."
	cd manifests && while ! kustomize build common/oauth2-proxy/overlays/m2m-dex-only/ | kubectl apply -f -; do echo "Retrying oauth2-proxy/overlays/m2m-dex-only..."; sleep 10; done
	cd manifests && kubectl wait --for=condition=Ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy
	cd manifests && echo "Installing Dex..."
	cd manifests && while ! kustomize build common/dex/overlays/oauth2-proxy | kubectl apply -f -; do echo "Retrying dex/overlays/oauth2-proxy..."; sleep 10; done
	cd manifests && kubectl wait --for=condition=Ready pods --all --timeout=180s -n auth
	cd manifests && while ! kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -; do echo "Retrying knative-serving/overlays/gateways..."; sleep 10; done
	cd manifests && while ! kustomize build common/istio-1-24/cluster-local-gateway/base | kubectl apply -f -; do echo "Retrying cluster-local-gateway/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/knative/knative-eventing/base | kubectl apply -f -; do echo "Retrying knative-eventing/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/kubeflow-namespace/base | kubectl apply -f -; do echo "Retrying kubeflow-namespace/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/networkpolicies/base | kubectl apply -f -; do echo "Retrying networkpolicies/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/kubeflow-roles/base | kubectl apply -f -; do echo "Retrying kubeflow-roles/base..."; sleep 10; done
	cd manifests && while ! kustomize build common/istio-1-24/kubeflow-istio-resources/base | kubectl apply -f -; do echo "Retrying kubeflow-istio-resources/base..."; sleep 10; done
	cd manifests && while ! kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -; do echo "Retrying pipeline/env/cert-manager/platform-agnostic-multi-user..."; sleep 10; done
	cd manifests && while ! kustomize build apps/kserve/kserve | kubectl apply --server-side --force-conflicts -f -; do echo "Retrying kserve/kserve..."; sleep 10; done
	cd manifests && while ! kustomize build apps/kserve/models-web-app/overlays/kubeflow | kubectl apply -f -; do echo "Retrying models-web-app/overlays/kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -; do echo "Retrying katib/upstream/installs/katib-with-kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/centraldashboard/overlays/oauth2-proxy | kubectl apply -f -; do echo "Retrying centraldashboard/overlays/oauth2-proxy..."; sleep 10; done
	cd manifests && while ! kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -; do echo "Retrying admission-webhook/upstream/overlays/cert-manager..."; sleep 10; done
	cd manifests && while ! kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -; do echo "Retrying notebook-controller/upstream/overlays/kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -; do echo "Retrying jupyter-web-app/upstream/overlays/istio..."; sleep 10; done
	cd manifests && while ! kustomize build apps/pvcviewer-controller/upstream/base | kubectl apply -f -; do echo "Retrying pvcviewer-controller/upstream/base..."; sleep 10; done
	cd manifests && while ! kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -; do echo "Retrying profiles/upstream/overlays/kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -; do echo "Retrying volumes-web-app/upstream/overlays/istio..."; sleep 10; done
	cd manifests && while ! kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -; do echo "Retrying tensorboards-web-app/upstream/overlays/istio..."; sleep 10; done
	cd manifests && while ! kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -; do echo "Retrying tensorboard-controller/upstream/overlays/kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply --server-side --force-conflicts -f -; do echo "Retrying training-operator/upstream/overlays/kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build common/user-namespace/base | kubectl apply -f -; do echo "Retrying user-namespace/base..."; sleep 10; done

make access-kubeflow:
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 \
	&& echo "Visit http://localhost:8080 to use kubeflow"


.PHONY: mlflow
mlflow:
	kubectl apply -f mlflow/mlflow-pv-pvc.yml
	helm repo add community-charts https://community-charts.github.io/helm-charts
	helm repo update
	helm install streamliner-mlflow community-charts/mlflow

.PHONY: delete-mlflow
delete-mlflow:
	helm uninstall streamliner-mlflow
	kubectl delete -f mlflow/mlflow-pv-pvc.yml

.PHONY: access-mlflow
access-mlflow:
	kubectl port-forward svc/streamliner-mlflow -n default 5000:5000 \
	&& echo "Visit http://localhost:5000 to use mlflow"

.PHONY: aim
aim:
	docker pull aimstack/aim:latest
	kind load docker-image aimstack/aim:latest --name=kubeflow
	kubectl apply -f aimstack/service.yml
	kubectl apply -f aimstack/deployment.yml

.PHONY: delete-aim
delete-aim:
	kubectl delete -f aimstack/deployment.yml
	kubectl delete -f aimstack/service.yml

access-aim:
	kubectl port-forward -n default svc/streamliner-aimstack 8080:80 \
	&& echo "Visit http://localhost:8080 to use aim"

.PHONY: lakefs
lakefs:
	helm repo add lakefs https://charts.lakefs.io
	helm repo update
	helm install streamliner-lakefs lakefs/lakefs

.PHONY: delete-lakefs
delete-lakefs:
	helm uninstall streamliner-lakefs

.PHONY: access-lakefs
access-lakefs:
	kubectl port-forward -n default svc/streamliner-lakefs 8000:80 \
	&& echo "Visit http://localhost:8000/setup to use aim"

all:
	$(MAKE) cluster
	$(MAKE) kubeflow
	$(MAKE) mlflow
	$(MAKE) aim
	$(MAKE) lakefs

destroy-all:
	$(MAKE) destroy-cluster
