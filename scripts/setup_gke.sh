#!/usr/bin/env bash
# =============================================================================
# setup_gke.sh
# =============================================================================
# PURPOSE:
#   Creates a Google Kubernetes Engine (GKE) cluster with a dedicated GPU node
#   pool so that NVIDIA NIM can be deployed in the next step.
#
# WHAT IS GKE?
#   Google Kubernetes Engine is a managed service that runs Kubernetes for you.
#   Kubernetes is a system that schedules and manages containerised applications
#   across a group of machines (called a "cluster"). You describe what you want
#   running, and Kubernetes keeps it running even if individual machines fail.
#
# HOW TO RUN:
#   1. Install the Google Cloud CLI: https://cloud.google.com/sdk/docs/install
#   2. Run: gcloud auth login
#   3. Run: gcloud config set project YOUR_PROJECT_ID
#   4. Run: bash scripts/setup_gke.sh
#
# COST WARNING:
#   A single NVIDIA L4 node costs approximately $0.70/hour when running.
#   Delete the node pool or the entire cluster when you are done with your demo.
#   See the README Cost Awareness section for deletion commands.
# =============================================================================

set -euo pipefail
# ↑ set -e  → exit immediately if any command fails
# ↑ set -u  → treat unset variables as errors (prevents silent bugs)
# ↑ set -o pipefail → catch failures inside pipes (e.g. cmd1 | cmd2)

# ---------------------------------------------------------------------------
# Configuration — edit these values to match your Google Cloud project
# ---------------------------------------------------------------------------

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-my-gcp-project}"   # Your GCP project ID
REGION="us-central1"                                    # Region to deploy into
ZONE="${REGION}-a"                                      # Specific availability zone
CLUSTER_NAME="neurocompass-cluster"                     # Name for the GKE cluster
GPU_NODE_POOL="gpu-pool"                                # Name for the GPU node pool
MACHINE_TYPE="g2-standard-4"                           # Machine type: 4 vCPUs, 1× L4 GPU
GPU_TYPE="nvidia-l4"                                    # GPU model (L4 is cost-effective for inference)
GPU_COUNT=1                                             # Number of GPUs per node
MIN_GPU_NODES=0                                         # Scale to 0 when idle to save money
MAX_GPU_NODES=1                                         # Maximum GPU nodes during peak usage

echo "==> Setting active GCP project to: ${PROJECT_ID}"
# gcloud config set project tells all subsequent gcloud commands which project
# to operate against, so you do not have to pass --project on every command.
gcloud config set project "${PROJECT_ID}"

echo "==> Enabling required Google Cloud APIs..."
# Many Google Cloud services are disabled by default in a new project.
# These three APIs must be enabled before you can create clusters or manage
# container images.
gcloud services enable \
  container.googleapis.com \    `# Kubernetes Engine API` \
  containerregistry.googleapis.com \  `# Container Registry (image storage)` \
  compute.googleapis.com              `# Compute Engine (the underlying VMs)`

echo "==> Creating GKE cluster: ${CLUSTER_NAME}"
# This creates the control plane for the cluster — the brain that schedules
# and manages all the containers. We use --no-enable-autoprovisioning here
# because we want explicit control over which node pools exist and what GPUs
# they carry.
#
# --release-channel "regular" → stable Kubernetes releases with periodic updates
# --workload-pool              → enables Workload Identity (secure pod-level auth)
gcloud container clusters create "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --release-channel "regular" \
  --workload-pool="${PROJECT_ID}.svc.id.goog" \
  --num-nodes=1 \
  --no-enable-autoprovisioning \
  --quiet

echo "==> Adding GPU node pool: ${GPU_NODE_POOL}"
# A "node pool" is a group of machines inside the cluster that share the same
# hardware configuration. We separate GPU nodes into their own pool so that:
#   1. The GPU nodes can scale independently (down to 0 when idle).
#   2. Non-GPU workloads (e.g. monitoring) stay on cheaper CPU nodes.
#
# --accelerator type=...,count=...  → attaches the GPU to every node in the pool
# --min-nodes 0                     → allows the pool to scale to zero (saves cost)
# --enable-autoscaling              → automatically adds/removes nodes based on demand
# --spot                            → uses preemptible VMs (~70% cheaper; may be
#                                     interrupted; acceptable for demos)
gcloud container node-pools create "${GPU_NODE_POOL}" \
  --cluster="${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --machine-type="${MACHINE_TYPE}" \
  --accelerator "type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest" \
  --num-nodes=1 \
  --min-nodes="${MIN_GPU_NODES}" \
  --max-nodes="${MAX_GPU_NODES}" \
  --enable-autoscaling \
  --spot \
  --quiet

echo "==> Fetching cluster credentials for kubectl"
# This command writes the cluster's connection details into your local
# ~/.kube/config file, which is the configuration file that kubectl reads
# every time you run a command like "kubectl get pods".
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"

echo "==> Installing NVIDIA GPU device drivers via DaemonSet"
# Kubernetes does not automatically install GPU drivers on new nodes.
# This command applies a DaemonSet — a pod that runs on every GPU node —
# which installs the correct NVIDIA kernel driver.
# Without this step, Kubernetes cannot schedule workloads that request a GPU.
kubectl apply -f \
  https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml

echo ""
echo "✅ GKE cluster '${CLUSTER_NAME}' is ready."
echo "   GPU node pool '${GPU_NODE_POOL}' will scale up when NIM is deployed."
echo ""
echo "Next step: run  bash scripts/deploy_nim.sh"
echo ""
echo "To delete ALL resources when finished:"
echo "  gcloud container clusters delete ${CLUSTER_NAME} --region ${REGION} --quiet"
