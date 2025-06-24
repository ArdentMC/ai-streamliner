@echo off
REM Copyright 2025 ArdentMC
REM
REM Licensed under the Apache License, Version 2.0 (the "License");
REM you may not use this file except in compliance with the License.
REM You may obtain a copy of the License at
REM
REM     http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.

REM Windows-native Makefile for AI-Streamliner
REM This provides similar functionality to the Linux Makefile without requiring WSL

setlocal enabledelayedexpansion

REM Set default kubeconfig path
set KUBEFLOW_CONFIG=%TEMP%\kubeflow-config

IF "%1"=="" (
    call :show_help
    exit /b
)

IF "%1"=="help" (
    call :show_help
    exit /b
)

IF "%1"=="cluster" (
    call :create_cluster
    exit /b
)

IF "%1"=="destroy-cluster" (
    call :destroy_cluster
    exit /b
)

IF "%1"=="kubeflow" (
    call :deploy_kubeflow
    exit /b
)

IF "%1"=="mlflow" (
    call :deploy_mlflow
    exit /b
)

IF "%1"=="delete-mlflow" (
    call :delete_mlflow
    exit /b
)

IF "%1"=="aim" (
    call :deploy_aim
    exit /b
)

IF "%1"=="delete-aim" (
    call :delete_aim
    exit /b
)

IF "%1"=="lakefs" (
    call :deploy_lakefs
    exit /b
)

IF "%1"=="delete-lakefs" (
    call :delete_lakefs
    exit /b
)

IF "%1"=="access" (
    call :access_all
    exit /b
)

IF "%1"=="access-kubeflow" (
    call :access_kubeflow
    exit /b
)

IF "%1"=="access-mlflow" (
    call :access_mlflow
    exit /b
)

IF "%1"=="access-aim" (
    call :access_aim
    exit /b
)

IF "%1"=="access-lakefs" (
    call :access_lakefs
    exit /b
)

IF "%1"=="streamliner" (
    call :deploy_streamliner
    exit /b
)

IF "%1"=="destroy-streamliner" (
    call :destroy_streamliner
    exit /b
)

IF "%1"=="check" (
    call :check_requirements
    exit /b
)

echo Unknown command: %1
call :show_help
exit /b 1

:show_help
echo AI-Streamliner Windows Native Commands
echo =====================================
echo.
echo Commands:
echo   cluster              - Create a new kind cluster for Kubeflow
echo   destroy-cluster      - Delete the kind cluster
echo   kubeflow             - Deploy Kubeflow
echo   mlflow               - Deploy MLflow
echo   delete-mlflow        - Delete MLflow
echo   aim                  - Deploy Aim
echo   delete-aim           - Delete Aim
echo   lakefs               - Deploy LakeFS
echo   delete-lakefs        - Delete LakeFS
echo   access               - Access all tools via port-forwarding
echo   access-kubeflow      - Access Kubeflow via port-forwarding
echo   access-mlflow        - Access MLflow via port-forwarding
echo   access-aim           - Access Aim via port-forwarding
echo   access-lakefs        - Access LakeFS via port-forwarding
echo   streamliner          - Deploy all AI-Streamliner components
echo   destroy-streamliner  - Destroy the entire AI-Streamliner deployment
echo   check                - Check system requirements
echo   help                 - Show this help message
echo.
exit /b 0

:check_requirements
echo Checking system requirements...

REM Check for Docker
docker version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker is not installed or not running
    echo Please install Docker Desktop from https://docs.docker.com/desktop/
    exit /b 1
) else (
    echo [OK] Docker is installed and running
)

REM Check for Kind
kind version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Kind is not installed
    echo Please install Kind from https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager
    echo You can install it with: choco install kind
    exit /b 1
) else (
    echo [OK] Kind is installed
)

REM Check for kubectl
kubectl version --client >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] kubectl is not installed
    echo Please install kubectl from https://kubernetes.io/docs/tasks/tools/#kubectl
    echo You can install it with: choco install kubernetes-cli
    exit /b 1
) else (
    echo [OK] kubectl is installed
)

REM Check for kustomize
kustomize version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] kustomize is not installed
    echo Please install kustomize from https://kubectl.docs.kubernetes.io/installation/kustomize/
    echo You can install it with: choco install kustomize
    exit /b 1
) else (
    echo [OK] kustomize is installed
)

REM Check for helm
helm version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] helm is not installed
    echo Please install helm from https://helm.sh/docs/intro/install/
    echo You can install it with: choco install kubernetes-helm
    exit /b 1
) else (
    echo [OK] helm is installed
)

REM Check for Docker resources
set "memory_found=false"
REM Redirect stderr to null to suppress Docker warning messages
for /f "tokens=*" %%i in ('docker info 2^>nul') do (
    echo %%i | findstr /C:"Total Memory:" >nul
    if !ERRORLEVEL! equ 0 (
        set memory_line=%%i
        set "memory_found=true"
        for /f "tokens=3" %%a in ("!memory_line!") do set memory_value=%%a
        set memory_value=!memory_value!
        
        REM Check if memory is in GiB format
        echo !memory_value! | findstr /r /c:"[0-9]*\.[0-9]*GiB" >nul
        if !ERRORLEVEL! equ 0 (
            set memory=!memory_value:~0,-3!
            if !memory! LSS 16 (
                echo [WARNING] Docker has less than 16GB RAM allocated: !memory! GB
            ) else (
                echo [OK] Docker has sufficient memory: !memory! GB
            )
        )
    )
)

if "%memory_found%"=="false" (
    echo [WARNING] Could not determine Docker memory allocation
    echo Please ensure Docker has at least 16GB RAM allocated in Docker Desktop settings
)

for /f "tokens=*" %%i in ('docker info 2^>nul ^| findstr "CPUs:"') do (
    set cpu_line=%%i
)
echo !cpu_line! | findstr /r /c:"CPUs: [0-9][0-9]*" >nul
if %ERRORLEVEL% equ 0 (
    for /f "tokens=2" %%a in ("!cpu_line!") do set cpus=%%a
    if !cpus! LSS 8 (
        echo [WARNING] Docker has less than 8 CPU cores allocated: !cpus! cores
        echo Please increase CPU allocation in Docker Desktop settings
    ) else (
        echo [OK] Docker has sufficient CPU cores: !cpus! cores
    )
)

echo.
echo All required tools are installed.
exit /b 0

:create_cluster
echo Creating kind cluster for Kubeflow...

REM Check if cluster already exists
kind get clusters | findstr "^kubeflow$" >nul
if %ERRORLEVEL% equ 0 (
    echo Cluster 'kubeflow' already exists
) else (
    kind create cluster --name=kubeflow --config=cluster.yml
    kind get kubeconfig --name kubeflow > %KUBEFLOW_CONFIG%
    set KUBECONFIG=%KUBEFLOW_CONFIG%
)

REM Check if regcred secret exists
kubectl get secret regcred >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Docker registry secret 'regcred' already exists
) else (
    docker login
    kubectl create secret generic regcred --from-file=.dockerconfigjson=%USERPROFILE%\.docker\config.json --type=kubernetes.io/dockerconfigjson
)

echo Cluster setup complete.
exit /b 0

:destroy_cluster
echo Deleting kind cluster...
kind delete cluster --name=kubeflow
echo Cluster deleted.
exit /b 0

:deploy_kubeflow
echo Deploying Kubeflow...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

if exist manifests (
    echo Removing existing manifests directory...
    rmdir /s /q manifests
)

if exist kubeflow (
    echo Removing existing kubeflow directory...
    rmdir /s /q kubeflow
)

echo Cloning Kubeflow manifests repository...
git clone https://github.com/kubeflow/manifests.git
cd manifests && git fetch origin && git checkout -b v1.10-branch origin/v1.10-branch

echo Installing cert-manager...
cd manifests
:retry_cert_manager
kustomize build common/cert-manager/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying cert-manager/base...
    timeout /t 10 /nobreak
    goto :retry_cert_manager
)

:retry_cert_manager_issuer
kustomize build common/cert-manager/kubeflow-issuer/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying cert-manager/kubeflow-issuer/base...
    timeout /t 10 /nobreak
    goto :retry_cert_manager_issuer
)

echo Waiting for cert-manager to be ready...
kubectl wait --for=condition=Ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
kubectl wait --for=jsonpath='{.subsets[0].addresses[0].targetRef.kind}'=Pod endpoints -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager

echo Installing Istio configured with external authorization...
:retry_istio_crds
kustomize build common/istio-1-24/istio-crds/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying istio-crds/base...
    timeout /t 10 /nobreak
    goto :retry_istio_crds
)

:retry_istio_namespace
kustomize build common/istio-1-24/istio-namespace/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying istio-namespace/base...
    timeout /t 10 /nobreak
    goto :retry_istio_namespace
)

:retry_istio_install
kustomize build common/istio-1-24/istio-install/overlays/oauth2-proxy | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying istio-install/overlays/oauth2-proxy...
    timeout /t 10 /nobreak
    goto :retry_istio_install
)

echo Waiting for all Istio Pods to become ready...
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=300s

echo Installing oauth2-proxy...
:retry_oauth2_proxy
kustomize build common/oauth2-proxy/overlays/m2m-dex-only/ | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying oauth2-proxy/overlays/m2m-dex-only...
    timeout /t 10 /nobreak
    goto :retry_oauth2_proxy
)
kubectl wait --for=condition=Ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy

echo Installing Dex...
:retry_dex
kustomize build common/dex/overlays/oauth2-proxy | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying dex/overlays/oauth2-proxy...
    timeout /t 10 /nobreak
    goto :retry_dex
)
kubectl wait --for=condition=Ready pods --all --timeout=180s -n auth

echo Installing Knative Serving...
:retry_knative_serving
kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying knative-serving/overlays/gateways...
    timeout /t 10 /nobreak
    goto :retry_knative_serving
)

echo Installing Cluster Local Gateway...
:retry_cluster_local_gateway
kustomize build common/istio-1-24/cluster-local-gateway/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying cluster-local-gateway/base...
    timeout /t 10 /nobreak
    goto :retry_cluster_local_gateway
)

echo Installing Knative Eventing...
:retry_knative_eventing
kustomize build common/knative/knative-eventing/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying knative-eventing/base...
    timeout /t 10 /nobreak
    goto :retry_knative_eventing
)

echo Creating Kubeflow namespace...
:retry_kubeflow_namespace
kustomize build common/kubeflow-namespace/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying kubeflow-namespace/base...
    timeout /t 10 /nobreak
    goto :retry_kubeflow_namespace
)

echo Setting up network policies...
:retry_networkpolicies
kustomize build common/networkpolicies/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying networkpolicies/base...
    timeout /t 10 /nobreak
    goto :retry_networkpolicies
)

echo Setting up Kubeflow roles...
:retry_kubeflow_roles
kustomize build common/kubeflow-roles/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying kubeflow-roles/base...
    timeout /t 10 /nobreak
    goto :retry_kubeflow_roles
)

echo Installing Kubeflow Istio resources...
:retry_istio_resources
kustomize build common/istio-1-24/kubeflow-istio-resources/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying kubeflow-istio-resources/base...
    timeout /t 10 /nobreak
    goto :retry_istio_resources
)

echo Installing Kubeflow Pipeline...
:retry_pipeline
kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying pipeline/env/cert-manager/platform-agnostic-multi-user...
    timeout /t 10 /nobreak
    goto :retry_pipeline
)

echo Installing KServe...
set KSERVE_RETRIES=0
:retry_kserve
set CURRENT_DIR=%CD%
kustomize build %CURRENT_DIR%\apps\kserve\kserve | kubectl apply --server-side --force-conflicts -f -
if %ERRORLEVEL% neq 0 (
    set /a KSERVE_RETRIES+=1
    if !KSERVE_RETRIES! gtr 20 (
        echo Maximum retries reached for KServe. Continuing with installation...
    ) else (
        echo Retrying kserve/kserve with absolute path... Attempt !KSERVE_RETRIES! of 20
        timeout /t 10 /nobreak
        goto :retry_kserve
    )
)

echo Installing KServe Web App...
set KSERVE_WEB_RETRIES=0
:retry_kserve_web
set CURRENT_DIR=%CD%
kustomize build %CURRENT_DIR%\apps\kserve\models-web-app\overlays\kubeflow | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    set /a KSERVE_WEB_RETRIES+=1
    if !KSERVE_WEB_RETRIES! gtr 20 (
        echo Maximum retries reached for KServe Web App. Continuing with installation...
    ) else (
        echo Retrying models-web-app/overlays/kubeflow with absolute path... Attempt !KSERVE_WEB_RETRIES! of 20
        timeout /t 10 /nobreak
        goto :retry_kserve_web
    )
)

echo Installing Katib...
:retry_katib
kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying katib/upstream/installs/katib-with-kubeflow...
    timeout /t 10 /nobreak
    goto :retry_katib
)

echo Installing Central Dashboard...
:retry_centraldashboard
set CURRENT_DIR=%CD%
kustomize build %CURRENT_DIR%\apps\centraldashboard\overlays\oauth2-proxy | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying centraldashboard/overlays/oauth2-proxy with absolute path...
    timeout /t 10 /nobreak
    goto :retry_centraldashboard
)

echo Setting up custom theme for Kubeflow...
cd ..
if not exist kubeflow (
    git clone https://github.com/kubeflow/kubeflow.git
)

echo Copying theme files...
copy kubeflow-theme\kubeflow-palette.css kubeflow\components\centraldashboard\public\kubeflow-palette.css
copy kubeflow-theme\logo.svg kubeflow\components\centraldashboard\public\assets\logo.svg
copy kubeflow-theme\favicon.ico kubeflow\components\centraldashboard\public\assets\favicon.ico

echo Customizing colors in centraldashboard...
cd kubeflow\components\centraldashboard
for /r %%f in (*.js, *.ts, *.css, *.html, *.json) do (
    powershell -Command "(Get-Content '%%f') -replace '007dfc', 'fc0000' | Set-Content '%%f'"
    powershell -Command "(Get-Content '%%f') -replace '003c75', '750000' | Set-Content '%%f'"
    powershell -Command "(Get-Content '%%f') -replace '2196f3', 'f32121' | Set-Content '%%f'"
    powershell -Command "(Get-Content '%%f') -replace '0a3b71', '3b0a0a' | Set-Content '%%f'"
)

powershell -Command "(Get-Content 'public\index.html') -replace '<title>Kubeflow Central Dashboard</title>', '<title>AI Streamliner</title>' | Set-Content 'public\index.html'"
powershell -Command "(Get-Content 'public\components\main-page.pug') -replace 'https://github.com/kubeflow/kubeflow', 'https://github.com/ArdentMC/ai-streamliner' | Set-Content 'public\components\main-page.pug'"
powershell -Command "(Get-Content 'public\components\main-page.pug') -replace 'https://www.kubeflow.org/docs/about/kubeflow/', 'https://github.com/ArdentMC/ai-streamliner?tab=readme-ov-file#ai-streamliner' | Set-Content 'public\components\main-page.pug'"

echo Building custom centraldashboard Docker image...
docker build -t centraldashboard:dev .
kind load docker-image centraldashboard:dev --name=kubeflow
cd ..\..\..

echo Applying updated centraldashboard...
cd manifests
:retry_centraldashboard_again
set CURRENT_DIR=%CD%
kustomize build %CURRENT_DIR%\apps\centraldashboard\overlays\oauth2-proxy | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying centraldashboard/overlays/oauth2-proxy with absolute path...
    timeout /t 10 /nobreak
    goto :retry_centraldashboard_again
)

echo Creating centraldashboard overlays directory...
if not exist apps\centraldashboard\overlays\apps mkdir apps\centraldashboard\overlays\apps
if not exist apps\centraldashboard\overlays\apps\patches mkdir apps\centraldashboard\overlays\apps\patches
copy ..\kubeflow-config\kustomization.yaml apps\centraldashboard\overlays\apps\kustomization.yaml
copy ..\kubeflow-config\apps\patches\configmap.yaml apps\centraldashboard\overlays\apps\patches\configmap.yaml

echo Using absolute path for kustomize build...
set CURRENT_DIR=%CD%

:retry_centraldashboard_apps
kustomize build %CURRENT_DIR%\apps\centraldashboard\overlays\apps | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying centraldashboard/overlays/apps with absolute path...
    timeout /t 10 /nobreak
    goto :retry_centraldashboard_apps
)

echo Installing admission webhook...
:retry_admission_webhook
kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying admission-webhook/upstream/overlays/cert-manager...
    timeout /t 10 /nobreak
    goto :retry_admission_webhook
)

echo Installing notebook controller...
:retry_notebook_controller
kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying notebook-controller/upstream/overlays/kubeflow...
    timeout /t 10 /nobreak
    goto :retry_notebook_controller
)

echo Installing Jupyter web app...
:retry_jupyter_web_app
kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying jupyter-web-app/upstream/overlays/istio...
    timeout /t 10 /nobreak
    goto :retry_jupyter_web_app
)

echo Installing PVC viewer controller...
:retry_pvcviewer
kustomize build apps/pvcviewer-controller/upstream/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying pvcviewer-controller/upstream/base...
    timeout /t 10 /nobreak
    goto :retry_pvcviewer
)

echo Installing profiles...
:retry_profiles
kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying profiles/upstream/overlays/kubeflow...
    timeout /t 10 /nobreak
    goto :retry_profiles
)

echo Installing volumes web app...
:retry_volumes_web_app
kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying volumes-web-app/upstream/overlays/istio...
    timeout /t 10 /nobreak
    goto :retry_volumes_web_app
)

echo Installing tensorboards web app...
:retry_tensorboards_web_app
kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying tensorboards-web-app/upstream/overlays/istio...
    timeout /t 10 /nobreak
    goto :retry_tensorboards_web_app
)

echo Installing tensorboard controller...
:retry_tensorboard_controller
kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying tensorboard-controller/upstream/overlays/kubeflow...
    timeout /t 10 /nobreak
    goto :retry_tensorboard_controller
)

echo Installing training operator...
:retry_training_operator
kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply --server-side --force-conflicts -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying training-operator/upstream/overlays/kubeflow...
    timeout /t 10 /nobreak
    goto :retry_training_operator
)

echo Installing user namespace...
:retry_user_namespace
kustomize build common/user-namespace/base | kubectl apply -f -
if %ERRORLEVEL% neq 0 (
    echo Retrying user-namespace/base...
    timeout /t 10 /nobreak
    goto :retry_user_namespace
)

cd ..
echo Cleaning up temporary files...
rmdir /s /q manifests
rmdir /s /q kubeflow

echo Kubeflow deployment completed.
exit /b 0

:deploy_mlflow
echo Deploying MLflow...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

REM Check if PV exists
kubectl get pv mlflow-pv >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo MLflow PV/PVC already exists
) else (
    kubectl apply -f mlflow/mlflow-pv-pvc.yml
)

REM Add helm repo if needed
helm repo list | findstr "^community-charts" >nul
if %ERRORLEVEL% neq 0 (
    helm repo add community-charts https://community-charts.github.io/helm-charts
)
helm repo update

REM Install MLflow via helm
helm list | findstr "^streamliner-mlflow" >nul
if %ERRORLEVEL% equ 0 (
    echo MLflow helm release already exists
) else (
    helm install streamliner-mlflow community-charts/mlflow
)

echo MLflow deployment completed.
exit /b 0

:delete_mlflow
echo Deleting MLflow...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

helm uninstall streamliner-mlflow
kubectl delete -f mlflow/mlflow-pv-pvc.yml

echo MLflow deleted.
exit /b 0

:deploy_aim
echo Deploying Aim...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

docker pull aimstack/aim:latest
kind load docker-image aimstack/aim:latest --name=kubeflow

REM Check if service exists
kubectl get service streamliner-aimstack >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo AIM service already exists
) else (
    kubectl apply -f aimstack/service.yml
)

REM Check if deployment exists
kubectl get deployment streamliner-aimstack >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo AIM deployment already exists
) else (
    kubectl apply -f aimstack/deployment.yml
)

echo Aim deployment completed.
exit /b 0

:delete_aim
echo Deleting Aim...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

kubectl delete -f aimstack/deployment.yml
kubectl delete -f aimstack/service.yml

echo Aim deleted.
exit /b 0

:deploy_lakefs
echo Deploying LakeFS...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

REM Add helm repo if needed
helm repo list | findstr "^lakefs" >nul
if %ERRORLEVEL% neq 0 (
    helm repo add lakefs https://charts.lakefs.io
)
helm repo update

REM Install LakeFS via helm
helm list | findstr "^streamliner-lakefs" >nul
if %ERRORLEVEL% equ 0 (
    echo LakeFS helm release already exists
) else (
    helm install streamliner-lakefs lakefs/lakefs
)

echo LakeFS deployment completed.
exit /b 0

:delete_lakefs
echo Deleting LakeFS...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

helm uninstall streamliner-lakefs

echo LakeFS deleted.
exit /b 0

:access_kubeflow
echo Starting port-forwarding for Kubeflow...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

echo Waiting for Kubeflow pods to be ready...
:wait_for_kubeflow_pod
kubectl get deployment centraldashboard -n kubeflow >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Kubeflow centraldashboard not found yet, checking istio-ingressgateway...
    kubectl get -n istio-system deployment/istio-ingressgateway -o jsonpath="{.status.readyReplicas}" | findstr "1" >nul
    if %ERRORLEVEL% neq 0 (
        echo Kubeflow is not ready yet... waiting 10 seconds
        timeout /t 10 /nobreak >nul
        goto :wait_for_kubeflow_pod
    )
) else (
    kubectl get deployment centraldashboard -n kubeflow -o jsonpath="{.status.readyReplicas}" | findstr "1" >nul
    if %ERRORLEVEL% neq 0 (
        echo Kubeflow centraldashboard exists but not ready yet... waiting 10 seconds
        timeout /t 10 /nobreak >nul
        goto :wait_for_kubeflow_pod
    ) else (
        echo Kubeflow is ready!
    )
)

start "Kubeflow Port Forward" cmd /c kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
echo Visit http://localhost:8080 to use Kubeflow
start http://localhost:8080

echo Press Ctrl+C to stop port-forwarding when done.
exit /b 0

:access_mlflow
echo Starting port-forwarding for MLflow...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

echo Waiting for MLflow pod to be ready...
:wait_for_mlflow_pod
kubectl get pod -l app.kubernetes.io/name=mlflow -o jsonpath="{.items[0].status.phase}" | findstr "Running" >nul
if %ERRORLEVEL% neq 0 (
    echo MLflow is not ready yet... waiting 10 seconds
    timeout /t 10 /nobreak >nul
    goto :wait_for_mlflow_pod
) else (
    echo MLflow is ready!
)

start "MLflow Port Forward" cmd /c kubectl port-forward svc/streamliner-mlflow -n default 8083:5000
echo Visit http://localhost:8083 to use MLflow
start http://localhost:8083

echo Press Ctrl+C to stop port-forwarding when done.
exit /b 0

:access_aim
echo Starting port-forwarding for Aim...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

echo Waiting for AIM pod to be ready...
:wait_for_aim_pod
kubectl get pod -l app=streamliner-aimstack -o jsonpath="{.items[0].status.phase}" | findstr "Running" >nul
if %ERRORLEVEL% neq 0 (
    echo AIM is not ready yet... waiting 10 seconds
    timeout /t 10 /nobreak >nul
    goto :wait_for_aim_pod
) else (
    echo AIM is ready!
)

start "Aim Port Forward" cmd /c kubectl port-forward -n default svc/streamliner-aimstack 8081:80
echo Visit http://localhost:8081 to use Aim
start http://localhost:8081

echo Press Ctrl+C to stop port-forwarding when done.
exit /b 0

:access_lakefs
echo Starting port-forwarding for LakeFS...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

echo Waiting for LakeFS pod to be ready...
:wait_for_lakefs_pod
kubectl get pod -l app.kubernetes.io/name=lakefs -o jsonpath="{.items[0].status.phase}" | findstr "Running" >nul
if %ERRORLEVEL% neq 0 (
    echo LakeFS is not ready yet... waiting 10 seconds
    timeout /t 10 /nobreak >nul
    goto :wait_for_lakefs_pod
) else (
    echo LakeFS is ready!
)

start "LakeFS Port Forward" cmd /c kubectl port-forward -n default svc/streamliner-lakefs 8082:80
echo Visit http://localhost:8082/setup to use LakeFS
start http://localhost:8082

echo Press Ctrl+C to stop port-forwarding when done.
exit /b 0

:access_all
echo Starting port-forwarding for all services...

REM Set KUBECONFIG
set KUBECONFIG=%KUBEFLOW_CONFIG%
echo Using KUBECONFIG=%KUBECONFIG%

echo Waiting for all pods to be ready...
echo This may take a few minutes, please be patient.

REM Wait for Kubeflow pods
echo Checking Kubeflow pods...
:wait_for_kubeflow
kubectl get deployment centraldashboard -n kubeflow >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Kubeflow centraldashboard not found yet, checking istio-ingressgateway...
    kubectl get -n istio-system deployment/istio-ingressgateway -o jsonpath="{.status.readyReplicas}" | findstr "1" >nul
    if %ERRORLEVEL% neq 0 (
        echo Kubeflow is not ready yet... waiting 10 seconds
        timeout /t 10 /nobreak >nul
        goto :wait_for_kubeflow
    )
) else (
    kubectl get deployment centraldashboard -n kubeflow -o jsonpath="{.status.readyReplicas}" | findstr "1" >nul
    if %ERRORLEVEL% neq 0 (
        echo Kubeflow centraldashboard exists but not ready yet... waiting 10 seconds
        timeout /t 10 /nobreak >nul
        goto :wait_for_kubeflow
    ) else (
        echo Kubeflow is ready!
    )
)

REM Wait for MLflow pod
echo Checking MLflow pod...
:wait_for_mlflow
kubectl get pod -l app.kubernetes.io/name=mlflow -o jsonpath="{.items[0].status.phase}" | findstr "Running" >nul
if %ERRORLEVEL% neq 0 (
    echo MLflow is not ready yet... waiting 10 seconds
    timeout /t 10 /nobreak >nul
    goto :wait_for_mlflow
) else (
    echo MLflow is ready!
)

REM Wait for AIM pod
echo Checking AIM pod...
:wait_for_aim
kubectl get pod -l app=streamliner-aimstack -o jsonpath="{.items[0].status.phase}" | findstr "Running" >nul
if %ERRORLEVEL% neq 0 (
    echo AIM is not ready yet... waiting 10 seconds
    timeout /t 10 /nobreak >nul
    goto :wait_for_aim
) else (
    echo AIM is ready!
)

REM Wait for LakeFS pod
echo Checking LakeFS pod...
:wait_for_lakefs
kubectl get pod -l app.kubernetes.io/name=lakefs -o jsonpath="{.items[0].status.phase}" | findstr "Running" >nul
if %ERRORLEVEL% neq 0 (
    echo LakeFS is not ready yet... waiting 10 seconds
    timeout /t 10 /nobreak >nul
    goto :wait_for_lakefs
) else (
    echo LakeFS is ready!
)

echo All pods are running! Starting port-forwarding...

start "Kubeflow Port Forward" cmd /c kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
start "Aim Port Forward" cmd /c kubectl port-forward -n default svc/streamliner-aimstack 8081:80
start "LakeFS Port Forward" cmd /c kubectl port-forward -n default svc/streamliner-lakefs 8082:80
start "MLflow Port Forward" cmd /c kubectl port-forward svc/streamliner-mlflow -n default 8083:5000

echo Visit http://localhost:8080 to use Kubeflow
start http://localhost:8080

echo Services are running in separate windows. Close those windows to stop port-forwarding.
exit /b 0

:deploy_streamliner
echo Deploying all AI-Streamliner components...

call :create_cluster
call :deploy_kubeflow
call :deploy_mlflow
call :deploy_aim
call :deploy_lakefs

echo AI-Streamliner deployment completed.
exit /b 0

:destroy_streamliner
echo Destroying AI-Streamliner deployment...

call :destroy_cluster

echo AI-Streamliner destroyed.
exit /b 0
