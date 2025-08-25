#!/usr/bin/env bash
# Quiet Kubeflow installer with retries and logging
# Usage: install_kubeflow_quiet.sh /absolute/or/relative/path/to/logfile.log
set -euo pipefail

# Normalize log file to an absolute path so cd changes won't break logging
BASE_DIR="$(pwd -P)"
LOG_FILE="${1:-logs/kubeflow.log}"
case "$LOG_FILE" in
  /*) : ;; # already absolute
  *) LOG_FILE="$BASE_DIR/$LOG_FILE" ;;
esac
LOG_DIR="$(dirname "$LOG_FILE")"
mkdir -p "$LOG_DIR"
# Ensure log file exists and is writable
: >"$LOG_FILE"

# Detect platform for sed -i portability
UNAME_S="$(uname -s)"
if [[ "$UNAME_S" == "Darwin" ]]; then
  SED_INPLACE=(sed -i '')
else
  SED_INPLACE=(sed -i)
fi

# Helper: run a command, append all output to log, show a brief banner
run() {
  # shellcheck disable=SC2124
  local desc="$1"; shift || true
  echo "$desc"
  # Redirect both stdout/stderr of the entire command
  { "$@"; } >>"$LOG_FILE" 2>&1
}

# Helper: retry a kustomize build | kubectl apply loop until success
retry_apply() {
  local desc="$1"; local kustomize_path="$2"; local extra_kubectl_opts="${3:-}"
  echo "$desc"
  while ! { cd "$BASE_DIR" && kustomize build "$kustomize_path" | kubectl apply ${extra_kubectl_opts} -f -; } >>"$LOG_FILE" 2>&1; do
    printf "."
    sleep 10
  done
  printf " done\n"
}

# Helper: wait with logging
wait_for() {
  # shellcheck disable=SC2124
  local desc="$1"; shift
  echo "$desc"
  { kubectl "$@"; } >>"$LOG_FILE" 2>&1
}

# Start
run "Cleaning any previous checkout..." rm -rf manifests kubeflow
run "Cloning Kubeflow manifests..." git clone https://github.com/kubeflow/manifests.git
run "Checking out manifests v1.10-branch..." bash -lc 'cd manifests && git fetch origin && git checkout -b v1.10-branch origin/v1.10-branch'

# cert-manager
retry_apply "Installing cert-manager..." "manifests/common/cert-manager/base"
retry_apply "Configuring Kubeflow issuer..." "manifests/common/cert-manager/kubeflow-issuer/base"
wait_for "Waiting for cert-manager pods..." wait --for=condition=Ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
wait_for "Waiting for cert-manager webhook endpoint..." wait --for=jsonpath='{.subsets[0].addresses[0].targetRef.kind}'=Pod endpoints -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager

# Istio
echo "Installing Istio (CRDs, namespace, control-plane)..."
retry_apply "- istio CRDs" "manifests/common/istio/istio-crds/base"
retry_apply "- istio namespace" "manifests/common/istio/istio-namespace/base"
retry_apply "- istio control-plane (oauth2-proxy overlay)" "manifests/common/istio/istio-install/overlays/oauth2-proxy"
wait_for "Waiting for Istio pods..." wait --for=condition=Ready pods --all -n istio-system --timeout=300s

# oauth2-proxy and Dex
retry_apply "Installing oauth2-proxy..." "manifests/common/oauth2-proxy/overlays/m2m-dex-only/"
wait_for "Waiting for oauth2-proxy pod..." wait --for=condition=Ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy
retry_apply "Installing Dex..." "manifests/common/dex/overlays/oauth2-proxy"
wait_for "Waiting for Dex pods..." wait --for=condition=Ready pods --all --timeout=180s -n auth

# Knative and gateways
echo "Installing Knative and gateways..."
retry_apply "- knative gateways" "manifests/common/knative/knative-serving/overlays/gateways"
retry_apply "- cluster-local-gateway" "manifests/common/istio/cluster-local-gateway/base"
retry_apply "- knative eventing" "manifests/common/knative/knative-eventing/base"

# Kubeflow core
echo "Setting up Kubeflow core namespaces, roles, and resources..."
retry_apply "- kubeflow namespace" "manifests/common/kubeflow-namespace/base"
retry_apply "- network policies" "manifests/common/networkpolicies/base"
retry_apply "- kubeflow roles" "manifests/common/kubeflow-roles/base"
retry_apply "- kubeflow istio resources" "manifests/common/istio/kubeflow-istio-resources/base"

# Applications
echo "Installing Pipelines, KServe, Katib, and Central Dashboard..."
retry_apply "- Pipelines (multi-user)" "manifests/applications/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user"
retry_apply "- KServe (server-side apply)" "manifests/applications/kserve/kserve" "--server-side --force-conflicts"
retry_apply "- KServe models web app" "manifests/applications/kserve/models-web-app/overlays/kubeflow"
retry_apply "- Katib" "manifests/applications/katib/upstream/installs/katib-with-kubeflow"
retry_apply "- Central Dashboard (oauth2-proxy overlay)" "manifests/applications/centraldashboard/overlays/oauth2-proxy"

# Customize Central Dashboard branding
run "Cloning kubeflow/kubeflow for centraldashboard branding..." git clone https://github.com/kubeflow/kubeflow.git && cd kubeflow/ && git checkout -t origin/v1.10-branch
run "Applying AI Streamliner theme files..." bash -lc 'cp kubeflow-theme/logo.svg kubeflow/components/centraldashboard/public/assets/logo.svg && cp kubeflow-theme/favicon.ico kubeflow/components/centraldashboard/public/assets/favicon.ico'

# Color replacements and page tweaks (run in current shell so SED_INPLACE array is available)
apply_color_tweaks() {
  local dir="kubeflow/components/centraldashboard"
  if [ ! -d "$dir" ]; then
    echo "Error: $dir not found" | tee -a "$LOG_FILE"
    return 1
  fi
  (
    cd "$dir" || exit 1
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec "${SED_INPLACE[@]}" 's/007dfc/fc0000/g' {} \;
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec "${SED_INPLACE[@]}" 's/003c75/750000/g' {} \;
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec "${SED_INPLACE[@]}" 's/2196f3/f32121/g' {} \;
    find . \( -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name '*.json' \) -exec "${SED_INPLACE[@]}" 's/0a3b71/3b0a0a/g' {} \;
    "${SED_INPLACE[@]}" 's/<title>Kubeflow Central Dashboard<\/title>/<title>AI Streamliner<\/title>/' public/index.html
    "${SED_INPLACE[@]}" 's|https://github.com/kubeflow/kubeflow|https://github.com/ArdentMC/ai-streamliner|g' public/components/main-page.pug
    "${SED_INPLACE[@]}" 's|https://www.kubeflow.org/docs/about/kubeflow/|https://github.com/ArdentMC/ai-streamliner?tab=readme-ov-file#ai-streamliner|g' public/components/main-page.pug
  )
}
run "Applying color tweaks..." apply_color_tweaks

run "Building centraldashboard image..." bash -lc 'cd kubeflow/components/centraldashboard && docker build -t centraldashboard:dev .'
run "Loading image into kind..." kind load docker-image centraldashboard:dev --name=aistreamliner

# Deploy customized dashboard + app overlay patches
retry_apply "Deploying customized Central Dashboard (oauth2-proxy overlay)..." "manifests/applications/centraldashboard/overlays/oauth2-proxy"
run "Copying overlay patches..." bash -lc 'cd manifests && mkdir -p applications/centraldashboard/overlays/apps/patches && cp ../manifests-config/kustomization.yaml applications/centraldashboard/overlays/apps/kustomization.yaml && cp ../manifests-config/apps/patches/configmap.yaml applications/centraldashboard/overlays/apps/patches/configmap.yaml'
retry_apply "Applying Central Dashboard app overlays..." "manifests/applications/centraldashboard/overlays/apps"

# Remaining apps
retry_apply "Applying admission-webhook (cert-manager overlay)..." "manifests/applications/admission-webhook/upstream/overlays/cert-manager"
retry_apply "Applying notebook-controller (kubeflow overlay)..." "manifests/applications/jupyter/notebook-controller/upstream/overlays/kubeflow"
retry_apply "Applying jupyter-web-app (istio overlay)..." "manifests/applications/jupyter/jupyter-web-app/upstream/overlays/istio"
retry_apply "Applying pvcviewer-controller (base)..." "manifests/applications/pvcviewer-controller/upstream/base"
retry_apply "Applying profiles (kubeflow overlay)..." "manifests/applications/profiles/upstream/overlays/kubeflow"
retry_apply "Applying volumes-web-app (istio overlay)..." "manifests/applications/volumes-web-app/upstream/overlays/istio"
retry_apply "Applying tensorboards-web-app (istio overlay)..." "manifests/applications/tensorboard/tensorboards-web-app/upstream/overlays/istio"
retry_apply "Applying tensorboard-controller (kubeflow overlay)..." "manifests/applications/tensorboard/tensorboard-controller/upstream/overlays/kubeflow"
retry_apply "Applying training-operator (server-side apply)..." "manifests/applications/training-operator/upstream/overlays/kubeflow" "--server-side --force-conflicts"
retry_apply "Creating user-namespace base..." "manifests/common/user-namespace/base"

# Cleanup
run "Cleaning up temporary checkouts..." rm -rf manifests kubeflow

echo "Kubeflow installation finished successfully. See log: $LOG_FILE"

