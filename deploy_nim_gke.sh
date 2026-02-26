#!/usr/bin/env bash
# NeuroCompass – GKE Infrastructure Setup & NVIDIA NIM Deployment
# Run these commands from a terminal with gcloud, kubectl, and helm installed.
# Ensure you are authenticated: gcloud auth login && gcloud auth configure-docker

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:?Set the GCP_PROJECT_ID environment variable}"
CLUSTER_NAME="${CLUSTER_NAME:-neurocompass-cluster}"
REGION="${GCP_REGION:-us-central1}"
NODE_POOL_NAME="gpu-node-pool"
MACHINE_TYPE="g2-standard-4"   # NVIDIA L4 GPU machine type
GPU_TYPE="nvidia-l4"
GPU_COUNT=1
# NGC_API_KEY must be set in the environment before running this script.
NGC_API_KEY="${NGC_API_KEY:?Set the NGC_API_KEY environment variable}"
NAMESPACE="nim"
# ─────────────────────────────────────────────────────────────────────────────

echo "==> Setting active GCP project..."
gcloud config set project "${PROJECT_ID}"

# Step 1: Create a GKE cluster with an NVIDIA L4 GPU node pool
echo "==> Creating GKE cluster: ${CLUSTER_NAME}..."
gcloud container clusters create "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --release-channel "regular" \
  --num-nodes 1 \
  --no-enable-autoupgrade  # Pinned for reproducibility; enable for long-lived clusters

echo "==> Adding NVIDIA L4 GPU node pool: ${NODE_POOL_NAME}..."
gcloud container node-pools create "${NODE_POOL_NAME}" \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --machine-type "${MACHINE_TYPE}" \
  --accelerator "type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-installation-config=google-managed" \
  --num-nodes 1 \
  --no-enable-autoupgrade  # Pinned for reproducibility; enable for long-lived clusters

echo "==> Fetching cluster credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}"

# Step 2: Create namespace and NGC API key secret for pulling NIM containers
echo "==> Creating Kubernetes namespace: ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating NVIDIA NGC API key secret..."
kubectl create secret docker-registry ngc-secret \
  --namespace "${NAMESPACE}" \
  --docker-server="nvcr.io" \
  --docker-username="\$oauthtoken" \
  --docker-password="${NGC_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Deploy the meta/llama3-8b-instruct NIM microservice via Helm
echo "==> Adding NVIDIA NIM Helm repository..."
helm repo add nvidia-nim https://helm.ngc.nvidia.com/nim/charts \
  --username="\$oauthtoken" \
  --password="${NGC_API_KEY}"
helm repo update

echo "==> Deploying meta/llama3-8b-instruct NIM microservice..."
helm install llama3-8b-instruct nvidia-nim/nim-llm \
  --namespace "${NAMESPACE}" \
  --set image.repository="nvcr.io/nim/meta/llama3-8b-instruct" \
  --set image.tag="1.0.0" \
  --set imagePullSecrets[0].name="ngc-secret" \
  --set resources.limits."nvidia\.com/gpu"=1 \
  --set service.type="ClusterIP" \
  --set service.port=8000 \
  --wait --timeout=10m

echo ""
echo "==> Deployment complete!"
echo "==> To access the NIM endpoint locally, run:"
echo "    kubectl port-forward svc/llama3-8b-instruct-nim-llm 8000:8000 -n ${NAMESPACE}"
echo "==> Then open chat_frontend.html in your browser."
