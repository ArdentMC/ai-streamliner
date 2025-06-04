cluster:
	@if ! kind get clusters | grep -q "^kubeflow$$"; then \
		kind create cluster --name=kubeflow --config=cluster.yml; \
		kind get kubeconfig --name kubeflow > /tmp/kubeflow-config; \
		export KUBECONFIG=/tmp/kubeflow-config; \
	else \
		echo "Cluster 'kubeflow' already exists"; \
	fi
	@if ! kubectl get secret regcred >/dev/null 2>&1; then \
		docker login; \
		kubectl create secret generic regcred \
			--from-file=.dockerconfigjson=$(HOME)/.docker/config.json \
			--type=kubernetes.io/dockerconfigjson; \
	else \
		echo "Docker registry secret 'regcred' already exists"; \
	fi

destroy-cluster:
	kind delete cluster --name=kubeflow

.PHONY: kubeflow
kubeflow:
	rm -rf manifests
	rm -rf kubeflow
	git clone https://github.com/kubeflow/manifests.git
	cd manifests && git fetch origin && git checkout -b v1.10-branch origin/v1.10-branch
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
	cd manifests && while ! kustomize build apps/kserve/kserve | kubectl apply --server-side --force-conflicts -f -; do echo "Retrying kserve/kserve... (This one takes several minutes)"; sleep 10; done
	cd manifests && while ! kustomize build apps/kserve/models-web-app/overlays/kubeflow | kubectl apply -f -; do echo "Retrying models-web-app/overlays/kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -; do echo "Retrying katib/upstream/installs/katib-with-kubeflow..."; sleep 10; done
	cd manifests && while ! kustomize build apps/centraldashboard/overlays/oauth2-proxy | kubectl apply -f -; do echo "Retrying centraldashboard/overlays/oauth2-proxy..."; sleep 10; done

	git clone https://github.com/kubeflow/kubeflow.git
	cp kubeflow-theme/kubeflow-palette.css kubeflow/components/centraldashboard/public/kubeflow-palette.css
	cp kubeflow-theme/logo.svg kubeflow/components/centraldashboard/public/assets/logo.svg
	cp kubeflow-theme/favicon.ico kubeflow/components/centraldashboard/public/assets/favicon.ico
	cd kubeflow/components/centraldashboard && find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i '' 's/007dfc/fc0000/g' {} +
	cd kubeflow/components/centraldashboard && find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i '' 's/003c75/750000/g' {} +
	cd kubeflow/components/centraldashboard && find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i '' 's/2196f3/f32121/g' {} +
	cd kubeflow/components/centraldashboard && find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec sed -i '' 's/0a3b71/3b0a0a/g' {} +
	cd kubeflow/components/centraldashboard && sed -i '' 's/<title>Kubeflow Central Dashboard<\/title>/<title>AI Streamliner<\/title>/' public/index.html
	cd kubeflow/components/centraldashboard && docker build -t centraldashboard:dev .
	kind load docker-image centraldashboard:dev --name=kubeflow

	cd manifests && while ! kustomize build apps/centraldashboard/overlays/oauth2-proxy | kubectl apply -f -; do echo "Retrying centraldashboard/overlays/oauth2-proxy..."; sleep 10; done
	cd manifests && mkdir -p apps/centraldashboard/overlays/apps/patches
	cd manifests && cp ../kubeflow-config/kustomization.yaml apps/centraldashboard/overlays/apps/kustomization.yaml
	cd manifests && cp ../kubeflow-config/apps/patches/configmap.yaml apps/centraldashboard/overlays/apps/patches/configmap.yaml
	cd manifests && while ! kustomize build apps/centraldashboard/overlays/apps | kubectl apply -f -; do echo "Retrying centraldashboard/overlays/apps..."; sleep 10; done

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
	rm -rf manifests
	rm -rf kubeflow

.PHONY: access-kubeflow
access-kubeflow:
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 \
	&& echo "Visit http://localhost:8080 to use Kubeflow"


.PHONY: mlflow
mlflow:
	@if ! kubectl get pv mlflow-pv >/dev/null 2>&1; then \
		kubectl apply -f mlflow/mlflow-pv-pvc.yml; \
	else \
		echo "MLflow PV/PVC already exists"; \
	fi
	@if ! helm repo list | grep -q "^community-charts"; then \
		helm repo add community-charts https://community-charts.github.io/helm-charts; \
	fi
	helm repo update
	@if ! helm list | grep -q "^streamliner-mlflow"; then \
		helm install streamliner-mlflow community-charts/mlflow; \
	else \
		echo "MLflow helm release already exists"; \
	fi

.PHONY: delete-mlflow
delete-mlflow:
	helm uninstall streamliner-mlflow
	kubectl delete -f mlflow/mlflow-pv-pvc.yml

.PHONY: access-mlflow
access-mlflow:
	kubectl port-forward svc/streamliner-mlflow -n default 8083:5000 \
	&& echo "Visit http://localhost:8083 to use MLflow"

.PHONY: aim
aim:
	docker pull aimstack/aim:latest
	kind load docker-image aimstack/aim:latest --name=kubeflow
	@if ! kubectl get service streamliner-aimstack >/dev/null 2>&1; then \
		kubectl apply -f aimstack/service.yml; \
	else \
		echo "AIM service already exists"; \
	fi
	@if ! kubectl get deployment streamliner-aimstack >/dev/null 2>&1; then \
		kubectl apply -f aimstack/deployment.yml; \
	else \
		echo "AIM deployment already exists"; \
	fi

.PHONY: delete-aim
delete-aim:
	kubectl delete -f aimstack/deployment.yml
	kubectl delete -f aimstack/service.yml

.PHONY: access-aim
access-aim:
	kubectl port-forward -n default svc/streamliner-aimstack 8081:80 \
	&& echo "Visit http://localhost:8081 to use Aim"

.PHONY: lakefs
lakefs:
	@if ! helm repo list | grep -q "^lakefs"; then \
		helm repo add lakefs https://charts.lakefs.io; \
	fi
	helm repo update
	@if ! helm list | grep -q "^streamliner-lakefs"; then \
		helm install streamliner-lakefs lakefs/lakefs; \
	else \
		echo "LakeFS helm release already exists"; \
	fi

.PHONY: delete-lakefs
delete-lakefs:
	helm uninstall streamliner-lakefs

.PHONY: access-lakefs
access-lakefs:
	kubectl port-forward -n default svc/streamliner-lakefs 8082:80 \
	&& echo "Visit http://localhost:8082/setup to use LakeFS"

.PHONY: access
access:
	@echo "Starting port-forwarding for Kubeflow, Aim, LakeFS, and MLflow..."
	@trap "kill 0" EXIT; \
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 & \
	echo "Visit http://localhost:8080 to use AI Streamliner" & \
	kubectl port-forward -n default svc/streamliner-aimstack 8081:80 & \
	kubectl port-forward -n default svc/streamliner-lakefs 8082:80 & \
	kubectl port-forward svc/streamliner-mlflow -n default 8083:5000 & \
	wait

streamliner:
	$(MAKE) cluster
	$(MAKE) kubeflow
	$(MAKE) mlflow
	$(MAKE) aim
	$(MAKE) lakefs

destroy-streamliner:
	$(MAKE) destroy-cluster

.PHONY: stop-lingering-port-forward
stop-lingering-port-forward:
	pkill -f "kubectl port-forward"
