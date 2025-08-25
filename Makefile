# Copyright 2025 ArdentMC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Cross-platform Makefile for AI Streamliner
# Works on macOS, Linux, and Windows with WSL

# Detect operating system
UNAME_S := $(shell uname -s)

# Set platform-specific commands and options
ifeq ($(UNAME_S),Darwin)
    # macOS specific settings
    SED_INPLACE := sed -i ''
    OPEN_CMD := open
else ifeq ($(UNAME_S),Linux)
    # Check if running in WSL (Windows Subsystem for Linux)
    ifeq ($(shell grep -i microsoft /proc/version 2>/dev/null),)
        # Native Linux
        SED_INPLACE := sed -i
        OPEN_CMD := xdg-open 2>/dev/null || sensible-browser 2>/dev/null || python3 -m webbrowser
    else
        # WSL (Windows Subsystem for Linux)
        SED_INPLACE := sed -i
        OPEN_CMD := cmd.exe /c start
    endif
else
    # Fallback to Linux defaults for other systems
    SED_INPLACE := sed -i
    OPEN_CMD := xdg-open 2>/dev/null || sensible-browser 2>/dev/null || python3 -m webbrowser
endif

# Check for kustomize command and use kubectl kustomize if needed
KUSTOMIZE := $(shell which kustomize 2>/dev/null)
ifeq ($(KUSTOMIZE),)
    KUSTOMIZE := kubectl kustomize
    KUSTOMIZE_BUILD := kubectl kustomize
else
    KUSTOMIZE_BUILD := kustomize build
endif

# Logging controls
LOG_DIR ?= logs

# Check for required dependencies
.PHONY: check-dependencies
check-dependencies:
	@echo "Checking required dependencies..."
	@(which kubectl > /dev/null) || (echo "Error: kubectl is not installed or not in PATH" && exit 1)
	@(which docker > /dev/null) || (echo "Error: docker is not installed or not in PATH" && exit 1)
	@(which kind > /dev/null) || (echo "Error: kind is not installed or not in PATH" && exit 1)
	@(which git > /dev/null) || (echo "Error: git is not installed or not in PATH" && exit 1)
	@(which helm > /dev/null) || (echo "Error: helm is not installed or not in PATH" && exit 1)
	@echo "All required dependencies are installed"

cluster: check-dependencies
	@if ! kind get clusters | grep -q "^aistreamliner$$"; then \
		kind create cluster --name=aistreamliner --config=cluster.yml; \
		if [ "$(UNAME_S)" = "Darwin" ] || [ "$(UNAME_S)" = "Linux" ]; then \
			kind get kubeconfig --name aistreamliner > /tmp/aistreamliner-config; \
			export KUBECONFIG=/tmp/aistreamliner-config; \
		else \
			kind get kubeconfig --name aistreamliner > $(shell echo %TEMP%)/aistreamliner-config; \
			export KUBECONFIG=$(shell echo %TEMP%)/aistreamliner-config; \
		fi; \
	else \
		echo "Cluster 'aistreamliner' already exists"; \
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
	kind delete cluster --name=aistreamliner

.PHONY: kubeflow
kubeflow: check-dependencies
	echo "Starting Kubeflow install (quiet). Detailed logs will be written to $(LOG_DIR)."; \
	mkdir -p $(LOG_DIR); \
	LOG_FILE=$(LOG_DIR)/kubeflow-$$(/bin/date +%Y%m%d-%H%M%S).log; \
	/bin/bash scripts/install_kubeflow_quiet.sh "$$LOG_FILE" || { echo "Kubeflow installation failed. See $$LOG_FILE"; exit 1; }; \
	echo "Kubeflow installation complete. Detailed logs at $$LOG_FILE"; \

.PHONY: access-kubeflow
access-kubeflow: check-dependencies
	@echo "Checking if Kubeflow is ready..."
	@kubectl get svc/istio-ingressgateway -n istio-system >/dev/null 2>&1 || { echo "Error: Kubeflow istio-ingressgateway not found. Is Kubeflow installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=60s deployment/istio-ingressgateway -n istio-system || echo "Warning: istio-ingressgateway not fully ready, but continuing..."
	
	@trap "kill 0" EXIT; \
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 & \
	echo "Visit http://localhost:8080 to use Kubeflow" & \
	$(OPEN_CMD) "http://localhost:8080" & \
	wait

.PHONY: mlflow
mlflow: check-dependencies
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
		helm install streamliner-mlflow community-charts/mlflow --version 0.17.2 -f mlflow/values.yaml; \
	else \
		echo "MLflow helm release already exists"; \
	fi

.PHONY: delete-mlflow
delete-mlflow:
	helm uninstall streamliner-mlflow
	kubectl delete -f mlflow/mlflow-pv-pvc.yml

.PHONY: access-mlflow
access-mlflow: check-dependencies
	@echo "Checking if MLflow is ready..."
	@kubectl get svc/streamliner-mlflow -n default >/dev/null 2>&1 || { echo "Error: MLflow service not found. Is MLflow installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=30s deployment/streamliner-mlflow -n default || echo "Warning: MLflow deployment not fully ready, but continuing..."
	
	@trap "kill 0" EXIT; \
	kubectl port-forward svc/streamliner-mlflow -n default 8083:5000 & \
	echo "Visit http://localhost:8083 to use MLflow" & \
	$(OPEN_CMD) "http://localhost:8083" & \
	wait


.PHONY: aim
aim: check-dependencies
	docker pull aimstack/aim:3.29.1
	kind load docker-image aimstack/aim:3.29.1 --name=aistreamliner
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
access-aim: check-dependencies
	@echo "Checking if Aim is ready..."
	@kubectl get svc/streamliner-aimstack -n default >/dev/null 2>&1 || { echo "Error: Aim service not found. Is Aim installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=30s deployment/streamliner-aimstack -n default || echo "Warning: Aim deployment not fully ready, but continuing..."
	
	@trap "kill 0" EXIT; \
	kubectl port-forward -n default svc/streamliner-aimstack 8081:80 & \
	echo "Visit http://localhost:8081 to use Aim" & \
	$(OPEN_CMD) "http://localhost:8081" & \
	wait

.PHONY: lakefs
lakefs: check-dependencies
	@if ! helm repo list | grep -q "^lakefs"; then \
		helm repo add lakefs https://charts.lakefs.io; \
	fi
	helm repo update
	@if ! helm list | grep -q "^streamliner-lakefs"; then \
		helm install streamliner-lakefs lakefs/lakefs --version 1.4.17; \
	else \
		echo "LakeFS helm release already exists"; \
	fi

.PHONY: delete-lakefs
delete-lakefs:
	helm uninstall streamliner-lakefs

.PHONY: access-lakefs
access-lakefs: check-dependencies
	@echo "Checking if LakeFS is ready..."
	@kubectl get svc/streamliner-lakefs -n default >/dev/null 2>&1 || { echo "Error: LakeFS service not found. Is LakeFS installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=30s deployment/streamliner-lakefs -n default || echo "Warning: LakeFS deployment not fully ready, but continuing..."
	
	@trap "kill 0" EXIT; \
	kubectl port-forward -n default svc/streamliner-lakefs 8082:80 & \
	echo "Visit http://localhost:8082/setup to use LakeFS" & \
	$(OPEN_CMD) "http://localhost:8082" & \
	wait

.PHONY: access
access: check-dependencies
	@echo "Checking if all services are ready before starting port-forwarding..."
	
	@echo "Checking Kubeflow (istio-ingressgateway)..."
	@kubectl get svc/istio-ingressgateway -n istio-system >/dev/null 2>&1 || { echo "Error: Kubeflow istio-ingressgateway not found. Is Kubeflow installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=60s deployment/istio-ingressgateway -n istio-system || echo "Warning: istio-ingressgateway not fully ready, but continuing..."
	
	@echo "Checking Aim..."
	@kubectl get svc/streamliner-aimstack -n default >/dev/null 2>&1 || { echo "Error: Aim service not found. Is Aim installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=30s deployment/streamliner-aimstack -n default || echo "Warning: Aim deployment not fully ready, but continuing..."
	
	@echo "Checking LakeFS..."
	@kubectl get svc/streamliner-lakefs -n default >/dev/null 2>&1 || { echo "Error: LakeFS service not found. Is LakeFS installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=30s deployment/streamliner-lakefs -n default || echo "Warning: LakeFS deployment not fully ready, but continuing..."
	
	@echo "Checking MLflow..."
	@kubectl get svc/streamliner-mlflow -n default >/dev/null 2>&1 || { echo "Error: MLflow service not found. Is MLflow installed?"; exit 1; }
	@kubectl wait --for=condition=available --timeout=30s deployment/streamliner-mlflow -n default || echo "Warning: MLflow deployment not fully ready, but continuing..."
	
	@echo "All services found. Starting port-forwarding..."
	@trap "kill 0" EXIT; \
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 & \
	echo "Visit http://localhost:8080 to use AI Streamliner" & \
	$(OPEN_CMD) "http://localhost:8080" & \
	kubectl port-forward -n default svc/streamliner-aimstack 8081:80 & \
	kubectl port-forward -n default svc/streamliner-lakefs 8082:80 & \
	kubectl port-forward svc/streamliner-mlflow -n default 8083:5000 & \
	wait

streamliner: check-dependencies
	$(MAKE) cluster
	$(MAKE) kubeflow
	$(MAKE) mlflow
	$(MAKE) aim
	$(MAKE) lakefs

destroy-streamliner:
	$(MAKE) destroy-cluster

.PHONY: stop-lingering-port-forward
stop-lingering-port-forward:
	@if [ "$(UNAME_S)" = "Darwin" ] || [ "$(UNAME_S)" = "Linux" ]; then \
		pkill -f "kubectl port-forward" || true; \
	else \
		taskkill /F /IM kubectl.exe /T || true; \
	fi

.PHONY: jupyter-notebook
jupyter-notebook:
	@echo "Starting Jupyter Notebook..."
	kubectl apply -f notebook.yaml
