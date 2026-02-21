#!/usr/bin/env bash
# =============================================================================
# deploy_nim.sh
# =============================================================================
# PURPOSE:
#   Deploys NVIDIA NIM (Llama 3) onto the GKE cluster created by setup_gke.sh
#   using Helm — the package manager for Kubernetes.
#
# WHAT IS NVIDIA NIM?
#   NIM stands for NVIDIA Inference Microservices. It is a pre-packaged
#   container from NVIDIA that:
#     • Downloads a large language model (we use Meta's Llama 3)
#     • Compiles it with TensorRT for maximum GPU throughput
#     • Exposes an OpenAI-compatible REST API (/v1/chat/completions)
#   You get a production-grade inference server without writing any model
#   serving code yourself.
#
# WHAT IS HELM?
#   Helm is to Kubernetes what "pip" is to Python or "apt" is to Ubuntu.
#   It packages all the Kubernetes YAML files needed to deploy an application
#   into a single "chart" that you can install with one command.
#
# PREREQUISITES:
#   1. setup_gke.sh has been run successfully.
#   2. helm is installed: https://helm.sh/docs/intro/install/
#   3. An NGC API key from https://ngc.nvidia.com (free account required).
#
# HOW TO RUN:
#   export NGC_API_KEY="your-key-here"
#   bash scripts/deploy_nim.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

NAMESPACE="nim"                          # Kubernetes namespace to deploy into
RELEASE_NAME="nim-llm"                   # Name Helm uses to track this deployment
NIM_CHART="nvidia/nim-llm"               # The Helm chart published by NVIDIA
NIM_MODEL="meta/llama3-8b-instruct"      # Which model NIM should serve
NIM_IMAGE="nvcr.io/nim/meta/llama3-8b-instruct:latest"  # Container image
HELM_REPO_URL="https://helm.ngc.nvidia.com/nvidia"       # NVIDIA's Helm repository URL

# Verify that the NGC API key has been set in the environment.
# Without this key, NIM cannot pull the model weights from NVIDIA's registry.
if [[ -z "${NGC_API_KEY:-}" ]]; then
  echo "❌ Error: NGC_API_KEY environment variable is not set."
  echo "   Get a free key at https://ngc.nvidia.com and run:"
  echo "   export NGC_API_KEY='your-key-here'"
  exit 1
fi

echo "==> Adding NVIDIA Helm repository"
# "helm repo add" registers a remote chart repository under a local alias.
# Think of it like adding a software source in a package manager.
# The --username and --password flags authenticate with NVIDIA's private registry.
helm repo add nvidia "${HELM_REPO_URL}" \
  --username='$oauthtoken' \
  --password="${NGC_API_KEY}"

echo "==> Refreshing Helm repository index"
# Downloads the latest list of available charts from all registered repositories.
# Always run this after adding a new repo to ensure you have the newest versions.
helm repo update

echo "==> Creating Kubernetes namespace: ${NAMESPACE}"
# A namespace is a virtual partition inside a Kubernetes cluster.
# Keeping NIM in its own namespace makes it easy to manage and delete.
# --dry-run=client -o yaml | kubectl apply -f - avoids errors if it already exists.
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating NGC registry pull secret"
# Kubernetes needs credentials to pull container images from private registries.
# This command stores the NGC API key as a Kubernetes "Secret" of type
# "docker-registry", which Kubernetes uses automatically when pulling the NIM image.
kubectl create secret docker-registry ngc-registry-secret \
  --namespace="${NAMESPACE}" \
  --docker-server="nvcr.io" \
  --docker-username='$oauthtoken' \
  --docker-password="${NGC_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -
# ↑ --dry-run=client | kubectl apply  → idempotent: safe to re-run without errors

echo "==> Deploying NVIDIA NIM via Helm"
# "helm upgrade --install" means:
#   • If the release does not exist yet → install it.
#   • If the release already exists → upgrade it to the new values.
# This makes the command safe to run multiple times.
#
# Key values explained:
#   image.repository / image.tag  → which container image to pull from nvcr.io
#   model.ngcAPIKey               → passed into the container so NIM can fetch weights
#   resources.limits              → requests exactly 1 GPU from the node pool
#   persistence.enabled           → caches model weights on disk so restarts are fast
helm upgrade --install "${RELEASE_NAME}" "${NIM_CHART}" \
  --namespace="${NAMESPACE}" \
  --set "image.repository=nvcr.io/nim/meta/llama3-8b-instruct" \
  --set "image.tag=latest" \
  --set "model.ngcAPIKey=${NGC_API_KEY}" \
  --set "model.name=${NIM_MODEL}" \
  --set "resources.limits.nvidia\.com/gpu=1" \
  --set "persistence.enabled=true" \
  --set "persistence.size=50Gi" \
  --set "imagePullSecrets[0].name=ngc-registry-secret" \
  --wait \
  --timeout 20m
# ↑ --wait --timeout 20m → Helm will block until the pod is Running or 20 min pass.
#   The first deployment takes ~10 minutes because NIM downloads and optimises
#   the model weights (several GB). Subsequent starts are faster thanks to the
#   persistent volume cache.

echo ""
echo "✅ NIM deployment complete."
echo ""
echo "To verify the pod is running:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "To stream the startup logs (watch TensorRT compilation progress):"
echo "  kubectl logs -n ${NAMESPACE} -l app=${RELEASE_NAME} -f"
echo ""
echo "To forward port 8000 to your laptop so the frontend can connect:"
echo "  kubectl port-forward -n ${NAMESPACE} service/${RELEASE_NAME} 8000:8000"
echo ""
echo "Then open frontend/index.html in your browser."
