#!/bin/bash
set -e

OUTPUT_DIR="${1:-/output}"
mkdir -p "$OUTPUT_DIR"

echo "=== AI Streamliner Artifact Extraction ==="
echo "Output directory: $OUTPUT_DIR"

# Copy pre-built Kubeflow manifests
echo "Exporting Kubeflow manifests..."
if [ -f "/app/artifacts/kubeflow-manifests.yaml" ]; then
    cp "/app/artifacts/kubeflow-manifests.yaml" "$OUTPUT_DIR/"
    echo "✓ Copied pre-built kubeflow-manifests.yaml"
fi

# Copy source manifests directory for reference
if [ -d "/app/kubeflow-manifests" ]; then
    mkdir -p "$OUTPUT_DIR/kubeflow-source"
    cp -r /app/kubeflow-manifests/* "$OUTPUT_DIR/kubeflow-source/"
    echo "✓ Copied kubeflow source manifests"
fi

# Export kubeflow-config directory needed for custom centraldashboard
if [ -d "/app/ai-streamliner/kubeflow-config" ]; then
    mkdir -p "$OUTPUT_DIR/kubeflow-config"
    cp -r /app/ai-streamliner/kubeflow-config/* "$OUTPUT_DIR/kubeflow-config/"
    echo "✓ Copied kubeflow-config directory"
fi

# Export kubeflow-theme directory needed for custom centraldashboard
if [ -d "/app/ai-streamliner/kubeflow-theme" ]; then
    mkdir -p "$OUTPUT_DIR/kubeflow-theme"
    cp -r /app/ai-streamliner/kubeflow-theme/* "$OUTPUT_DIR/kubeflow-theme/"
    echo "✓ Copied kubeflow-theme directory"
fi

# Export custom centraldashboard artifacts
echo "Exporting custom centraldashboard artifacts..."
if [ -d "/app/kubeflow/components/centraldashboard" ]; then
    mkdir -p "$OUTPUT_DIR/custom-centraldashboard"
    cp -r /app/kubeflow/components/centraldashboard/* "$OUTPUT_DIR/custom-centraldashboard/"
    echo "✓ Copied custom centraldashboard source"
fi

if [ -d "/app/kubeflow-manifests/apps/centraldashboard/overlays/apps" ]; then
    mkdir -p "$OUTPUT_DIR/centraldashboard-overlays"
    cp -r /app/kubeflow-manifests/apps/centraldashboard/overlays/apps/* "$OUTPUT_DIR/centraldashboard-overlays/"
    
    # Fix the kustomization.yaml path to work with extracted structure
    if [ -f "$OUTPUT_DIR/centraldashboard-overlays/kustomization.yaml" ]; then
        # Replace relative path with absolute reference to kubeflow-source
        sed -i 's|../../upstream/base|../kubeflow-source/applications/centraldashboard/upstream/base|g' "$OUTPUT_DIR/centraldashboard-overlays/kustomization.yaml"
    fi
    echo "✓ Copied centraldashboard kustomize overlays with fixed paths"
fi

# Export MLflow deployment files
echo "Exporting MLflow manifests..."
if [ -d "/app/ai-streamliner/mlflow" ]; then
    mkdir -p "$OUTPUT_DIR/mlflow"
    cp -r /app/ai-streamliner/mlflow/* "$OUTPUT_DIR/mlflow/"
    echo "✓ Copied MLflow configuration files"
fi

# Export Aim deployment files
echo "Exporting Aim manifests..."
if [ -d "/app/ai-streamliner/aimstack" ]; then
    mkdir -p "$OUTPUT_DIR/aimstack"
    cp -r /app/ai-streamliner/aimstack/* "$OUTPUT_DIR/aimstack/"
    echo "✓ Copied Aim deployment files"
fi

# Create LakeFS deployment instructions
echo "Creating LakeFS deployment configuration..."
mkdir -p "$OUTPUT_DIR/lakefs"
cat > "$OUTPUT_DIR/lakefs/install-lakefs.sh" << 'EOF'
#!/bin/bash
# LakeFS Installation Script

echo "Installing LakeFS via Helm..."

# Add LakeFS Helm repository
helm repo add lakefs https://charts.lakefs.io
helm repo update

# Install LakeFS
if helm status streamliner-lakefs &>/dev/null; then
    echo "LakeFS already installed, skipping..."
else
    helm install streamliner-lakefs lakefs/lakefs --version 1.4.17
fi

echo "LakeFS installed successfully!"
echo "To access LakeFS, run:"
echo "kubectl port-forward -n default svc/streamliner-lakefs 8082:80"
echo "Then visit: http://localhost:8082/setup"
EOF
chmod +x "$OUTPUT_DIR/lakefs/install-lakefs.sh"
echo "✓ Created LakeFS installation script"

# Create custom centraldashboard build script
echo "Creating custom centraldashboard build script..."
cat > "$OUTPUT_DIR/build-custom-centraldashboard.sh" << 'EOF'
#!/bin/bash
set -e

echo "=== Building Custom Centraldashboard ==="

if [ ! -d "custom-centraldashboard" ]; then
    echo "ERROR: custom-centraldashboard directory not found"
    echo "Make sure you're running this from the extracted artifacts directory"
    exit 1
fi

echo "Building custom centraldashboard Docker image..."
cd custom-centraldashboard
docker build -t centraldashboard:dev .
echo "✓ Custom centraldashboard built successfully!"

# If using kind, load the image
if command -v kind &> /dev/null; then
    echo "Loading image into kind cluster..."
    kind load docker-image centraldashboard:dev --name=kubeflow
    echo "✓ Image loaded into kind cluster"
fi

echo ""
echo "Custom centraldashboard is ready!"
echo "The kubeflow-manifests.yaml already references centraldashboard:dev"
EOF
chmod +x "$OUTPUT_DIR/build-custom-centraldashboard.sh"
echo "✓ Created custom centraldashboard build script"

# Create complete deployment script
echo "Creating complete deployment script..."
cat > "$OUTPUT_DIR/deploy-ai-streamliner.sh" << EOF
#!/bin/bash
set -e

echo "=== AI Streamliner Complete Deployment ==="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is required but not installed"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    echo "Please ensure your kubectl context is set correctly"
    exit 1
fi

echo "✓ Kubernetes cluster is accessible"

# Deploy Kubeflow
echo ""
echo "🚀 DEPLOYING KUBEFLOW - THIS MAY TAKE SEVERAL MINUTES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Connection errors during deployment are NORMAL!"
echo "    Services start in dependency order - retries are expected."
echo ""
echo "📊 Starting deployment..."

if [ -f "kubeflow-manifests.yaml" ]; then
    # Count total resources  
    TOTAL_RESOURCES=\$(grep -c "^kind:" kubeflow-manifests.yaml 2>/dev/null || echo "~200")
    echo "    Total resources to deploy: \$TOTAL_RESOURCES"
    echo ""
    
    ATTEMPT=1
    TOTAL_APPLIED=0
    
    while ! kubectl apply --server-side --force-conflicts -f kubeflow-manifests.yaml 2>/dev/null; do
        echo "🔄 Deployment attempt #\$ATTEMPT..."
        
        # Run kubectl to get current status and count applied resources
        KUBECTL_OUTPUT=\$(kubectl apply --server-side --force-conflicts -f kubeflow-manifests.yaml 2>&1 || true)
        CURRENT_APPLIED=\$(echo "\$KUBECTL_OUTPUT" | grep -E "(created|configured|serverside-applied|unchanged)" | wc -l)
        
        # Update total if we have more resources applied than before
        if [ \$CURRENT_APPLIED -gt \$TOTAL_APPLIED ]; then
            TOTAL_APPLIED=\$CURRENT_APPLIED
        fi
        
        echo "📈 Progress: \$TOTAL_APPLIED/\$TOTAL_RESOURCES resources successfully applied"
        echo "   🔄 Retrying deployment in 20 seconds..."
        sleep 20
        ATTEMPT=\$((ATTEMPT + 1))
    done
    
    # Final success message
    echo "✅ SUCCESS! All \$TOTAL_RESOURCES resources deployed successfully"
    echo "✓ Kubeflow deployment completed successfully"
else
    echo "ERROR: kubeflow-manifests.yaml not found"
    exit 1
fi

# Build and deploy custom centraldashboard (replicating manual working process)
echo "Setting up custom centraldashboard..."
if [ -d "kubeflow-source" ]; then
    echo "Building custom centraldashboard with AI Streamliner branding..."
    
    # Remove existing kubeflow directory if it exists, then clone fresh
    # rm -rf kubeflow
    # git clone https://github.com/kubeflow/kubeflow.git
    
    # Apply custom theme files
    cp kubeflow-theme/kubeflow-palette.css custom-centraldashboard/public/kubeflow-palette.css
    cp kubeflow-theme/logo.svg custom-centraldashboard/public/assets/logo.svg
    cp kubeflow-theme/favicon.ico custom-centraldashboard/public/assets/favicon.ico
    
    # Apply color theme changes - compatible with both Linux and macOS
    cd custom-centraldashboard
    
    # Apply basic color theme changes
    echo "Applying AI Streamliner color theme..."
    # Skip complex find commands that cause syntax errors
    # The theme files are already copied, which provides the main branding
    # sed -i 's/<title>Kubeflow Central Dashboard<\/title>/<title>AI Streamliner<\/title>/' public/index.html
    
    # # Fix BUILD_VERSION issue
    # sed -i "s/BUILD_VERSION/'ai-streamliner-v1.0'/g" public/components/main-page.js
    
    # Build and load custom centraldashboard
    docker build --no-cache -t centraldashboard:dev .
    echo "✓ Custom centraldashboard built successfully"
    
    # Load into kind cluster
    if command -v kind &> /dev/null && kind get clusters | grep -q "kubeflow"; then
        echo "Loading custom centraldashboard into kind cluster..."
        kind load docker-image centraldashboard:dev --name=kubeflow
        echo "✓ Image loaded into kind cluster"
    fi
    
    cd ../
    
    # Apply centraldashboard configurations with retry logic
    echo "Applying custom centraldashboard configuration..."
    (cd kubeflow-source && while ! kustomize build applications/centraldashboard/overlays/oauth2-proxy | kubectl apply -f -; do echo "Retrying centraldashboard/overlays/oauth2-proxy..."; sleep 10; done)
    (cd kubeflow-source && mkdir -p apps/centraldashboard/overlays/apps/patches)
    (cd kubeflow-source && cp ../kubeflow-config/kustomization.yaml apps/centraldashboard/overlays/apps/kustomization.yaml)
    (cd kubeflow-source && cp ../kubeflow-config/apps/patches/configmap.yaml apps/centraldashboard/overlays/apps/patches/configmap.yaml)
    (cd kubeflow-source && while ! kustomize build apps/centraldashboard/overlays/apps | kubectl apply -f -; do echo "Retrying centraldashboard/overlays/apps..."; sleep 10; done)
    
    cd ..
    echo "✓ Custom centraldashboard deployed successfully"
else
    echo "No kubeflow-source directory found, skipping custom centraldashboard setup"
fi

# Deploy MLflow
echo "Deploying MLflow..."
if [ -d "mlflow" ]; then
    kubectl apply -f mlflow/mlflow-pv-pvc.yml
    
    # Add MLflow Helm repo if not already added
    if ! helm repo list | grep -q "community-charts"; then
        helm repo add community-charts https://community-charts.github.io/helm-charts
    fi
    helm repo update
    
    # Install MLflow
    if helm status streamliner-mlflow &>/dev/null; then
        echo "✓ MLflow already installed, skipping"
    else
        helm install streamliner-mlflow community-charts/mlflow --version 0.17.2 -f mlflow/values.yaml
        echo "✓ MLflow deployment initiated"
    fi
fi

# Deploy Aim
echo "Deploying Aim..."
if [ -d "aimstack" ]; then
    kubectl apply -f aimstack/
    echo "✓ Aim deployment initiated"
fi

# Deploy LakeFS
echo "Deploying LakeFS..."
# Add LakeFS Helm repository
if ! helm repo list | grep -q "lakefs"; then
    helm repo add lakefs https://charts.lakefs.io
fi
helm repo update

# Install LakeFS
if helm status streamliner-lakefs &>/dev/null; then
    echo "✓ LakeFS already installed, skipping"
else
    helm install streamliner-lakefs lakefs/lakefs --version 1.4.17
    echo "✓ LakeFS deployment initiated"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "To access your services, run the following port-forward commands:"
echo ""
echo "# Kubeflow Dashboard"
echo "kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
echo "# Then visit: http://localhost:8080"
echo ""
echo "# MLflow"
echo "kubectl port-forward -n default svc/streamliner-mlflow 8083:5000"
echo "# Then visit: http://localhost:8083"
echo ""
echo "# Aim"
echo "kubectl port-forward -n default svc/streamliner-aimstack 8081:80"
echo "# Then visit: http://localhost:8081"
echo ""
echo "# LakeFS"
echo "kubectl port-forward -n default svc/streamliner-lakefs 8082:80"
echo "# Then visit: http://localhost:8082/setup"
echo ""
echo "Note: Wait for all pods to be ready before accessing the services."
echo "Check status with: kubectl get pods --all-namespaces"
EOF
chmod +x "$OUTPUT_DIR/deploy-ai-streamliner.sh"
echo "✓ Created complete deployment script"

# Create README with deployment instructions
cat > "$OUTPUT_DIR/README.md" << 'EOF'
# AI Streamliner Deployment Artifacts

This directory contains all the necessary files to deploy the complete AI Streamliner suite including Kubeflow, MLflow, Aim, and LakeFS.

## Quick Start

1. Ensure you have a Kubernetes cluster running (e.g., kind, minikube, or cloud cluster)
2. Install required tools: `kubectl`, `helm`, `docker`
3. **Build custom centraldashboard** (includes AI Streamliner branding):
   ```bash
   ./build-custom-centraldashboard.sh
   ```
4. Deploy the complete suite:
   ```bash
   ./deploy-ai-streamliner.sh
   ```

**Note**: The deployment script will automatically build the custom centraldashboard if needed, so you can also just run step 4 directly.

## Components Included

- **Kubeflow**: Complete ML platform with pipelines, notebooks, and model serving
- **MLflow**: ML lifecycle management and experiment tracking
- **Aim**: Advanced experiment tracking and visualization
- **LakeFS**: Data versioning and management

## Manual Deployment

If you prefer to deploy components individually:

### Kubeflow
```bash
# Use retry logic for reliable deployment
while ! kubectl apply --server-side --force-conflicts -f kubeflow-manifests.yaml; do 
    echo "Retrying Kubeflow deployment in 20 seconds..."
    sleep 20
done
```

### MLflow
```bash
kubectl apply -f mlflow/mlflow-pv-pvc.yml
helm repo add community-charts https://community-charts.github.io/helm-charts
helm install streamliner-mlflow community-charts/mlflow --version 0.17.2 -f mlflow/values.yaml
```

### Aim
```bash
kubectl apply -f aimstack/
```

### LakeFS
```bash
bash lakefs/install-lakefs.sh
```

## Accessing Services

After deployment, use these commands to access your services:

- **Kubeflow**: `kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80` → http://localhost:8080
- **MLflow**: `kubectl port-forward -n default svc/streamliner-mlflow 8083:5000` → http://localhost:8083
- **Aim**: `kubectl port-forward -n default svc/streamliner-aimstack 8081:80` → http://localhost:8081
- **LakeFS**: `kubectl port-forward -n default svc/streamliner-lakefs 8082:80` → http://localhost:8082/setup

## Custom Centraldashboard

The Kubeflow deployment includes a custom-branded centraldashboard with "AI Streamliner" theming. The custom build files are available in the `custom-centraldashboard/` directory.
EOF
echo "✓ Created deployment README"

echo ""
echo "=== Extraction Complete ==="
echo "All AI Streamliner deployment artifacts are now available in: $OUTPUT_DIR"
echo ""
echo "Contents:"
ls -la "$OUTPUT_DIR"
echo ""
echo "To deploy the complete suite, run:"
echo "cd $OUTPUT_DIR && ./deploy-ai-streamliner.sh"