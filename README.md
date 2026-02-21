# NeuroCompass 🧭

> **GPU-Accelerated Cognitive Drift Detection** — an end-to-end AI engineering portfolio project built on Google Cloud, NVIDIA RAPIDS, and Llama 3.

NeuroCompass is a full-stack AI application that processes large health and behavioral datasets on a GPU using NVIDIA's cuDF library, then serves a fine-tuned Llama 3 language model through NVIDIA NIM (Inference Microservices) on a Kubernetes cluster. A lightweight web frontend lets users chat with the model in real time. The project is designed to show every layer of a production AI system — from raw data on cloud storage all the way to a response in the browser — while remaining accessible to anyone who wants to learn how these technologies fit together.

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER BROWSER                           │
│                      frontend/index.html                       │
│              (chat UI with loading + error states)             │
└──────────────────────────┬──────────────────────────────────────┘
                           │  HTTP POST /v1/chat/completions
                           │  (OpenAI-compatible REST API)
┌──────────────────────────▼──────────────────────────────────────┐
│                   kubectl port-forward                          │
│              (tunnels traffic to the GKE cluster)              │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│               Google Kubernetes Engine (GKE)                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │   NVIDIA NIM Pod (Llama 3 · TensorRT-optimized)         │   │
│  │   GPU Node Pool  (NVIDIA L4 or A100)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│            Colab Enterprise (data pre-processing)              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │   scripts/process_data.py                               │   │
│  │   cuDF + Unified Virtual Memory (UVM)                   │   │
│  │   Reads Parquet from GCS → cleans → writes Parquet      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ How It Works — Step by Step

1. **Raw data lands in Google Cloud Storage** as Parquet files. Parquet is a column-based file format that lets you load only the columns you need, which is much faster than a traditional CSV when datasets are large.

2. **A GPU processes the data** (`scripts/process_data.py`). Instead of using regular pandas (which runs on CPU), the script uses **cuDF** — a drop-in pandas replacement that runs on the GPU. Unified Virtual Memory (UVM) is enabled so that if the dataset is larger than the GPU's memory, the overflow spills automatically into regular RAM instead of crashing.

3. **A Kubernetes cluster is created on Google Cloud** (`scripts/setup_gke.sh`). The cluster has a special *node pool* with a physical GPU attached to it (NVIDIA L4 or A100). This is where the AI model will live.

4. **NVIDIA NIM is deployed onto the cluster** (`scripts/deploy_nim.sh`). NIM is NVIDIA's pre-packaged inference server. It downloads the Llama 3 model weights, optimizes them with TensorRT for maximum GPU throughput, and exposes an OpenAI-compatible REST API endpoint.

5. **The browser connects to the model** via `kubectl port-forward`, which creates a secure tunnel from your laptop to the Kubernetes pod. The frontend (`frontend/index.html`) sends chat messages and displays the AI's structured responses.

---

## 👥 Who This Is For

| Audience | Why it's relevant |
|---|---|
| **ML engineers moving to production** | Shows how to take a model from a notebook to a real Kubernetes deployment |
| **Data engineers learning GPU acceleration** | Demonstrates cuDF as a drop-in pandas replacement with UVM safety |
| **Full-stack developers curious about AI** | Illustrates how a standard REST API connects a UI to a GPU-backed model |
| **Students building portfolio projects** | Each file is commented to explain *why*, not just *what* |

---

## 📚 What You Will Learn From This Repo

- How to store and load large datasets efficiently using **Apache Parquet**
- What **GPU acceleration** means in practice (and when it matters)
- How **Unified Virtual Memory** prevents out-of-memory crashes
- How to create and manage a **Kubernetes cluster** on Google Cloud with `gcloud` and `kubectl`
- How to deploy a production AI model using **Helm** charts
- What **NVIDIA NIM** is and why it is faster than running a model from scratch
- How to connect a browser frontend to a GPU-backed model via a REST API

---

## 🔑 Key Technology Glossary (Beginner-Friendly)

| Term | Plain English |
|---|---|
| **Parquet** | A smart file format for large tables. Instead of storing data row-by-row like a spreadsheet, it stores it column-by-column, so you can read only the columns you actually need. Much faster for analytics. |
| **cuDF** | Think of it as pandas, but it runs on your GPU instead of your CPU. You import it the same way and use the same function names — it just runs 10–100× faster on large datasets. |
| **Unified Virtual Memory (UVM)** | A safety net for GPU memory. If your dataset is bigger than the GPU's RAM, UVM automatically borrows space from the CPU's RAM rather than crashing the program. |
| **GKE (Google Kubernetes Engine)** | A managed service that lets you run containers (packaged applications) on a cluster of machines in the cloud. You describe what you want to run and Google manages the servers for you. |
| **NVIDIA NIM** | A ready-to-deploy container from NVIDIA that runs a large language model optimized for their GPUs. You deploy it like any other container, and it gives you an API that looks just like OpenAI's. |
| **TensorRT** | NVIDIA's compiler for AI models. It analyzes the model and rewrites it to run as fast as possible on the target GPU, reducing inference time significantly. |
| **Helm** | A package manager for Kubernetes — like `apt` or `pip`, but for deploying applications to a Kubernetes cluster. |

---

## 🚀 Quick Start

> **Prerequisites:** Google Cloud account, NVIDIA NGC API key, `gcloud` CLI, `kubectl`, `helm` installed locally.

**1. Clone the repository**
```bash
git clone https://github.com/zainkhan1994/goldenticket.git
cd goldenticket
```

**2. Authenticate with Google Cloud**
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

**3. Process the dataset on a GPU (run in Colab Enterprise)**
```bash
# Open scripts/process_data.py in Colab Enterprise
# Set your GCS bucket name at the top of the file, then run all cells
```

**4. Create the GKE cluster and GPU node pool**
```bash
bash scripts/setup_gke.sh
```

**5. Deploy NVIDIA NIM (Llama 3)**
```bash
export NGC_API_KEY="your-ngc-api-key-here"
bash scripts/deploy_nim.sh
```

**6. Forward the inference port to your local machine**
```bash
kubectl port-forward service/nim-llm 8000:8000
```

**7. Open the frontend**
```bash
# Open frontend/index.html in your browser
# The chat UI connects to http://localhost:8000 by default
```

---

## 💰 Cost Awareness

GPU instances on Google Cloud are expensive. Keep these points in mind to avoid unexpected charges:

| Action | Why it matters |
|---|---|
| **Delete the GPU node pool when not in use** | An NVIDIA L4 node costs roughly $0.70/hour even when idle. Run `gcloud container node-pools delete gpu-pool --cluster neurocompass-cluster` when finished. |
| **Set cluster auto-scaling to 0 minimum nodes** | The setup script configures `--min-nodes 0` so the GPU node scales down automatically when there are no pending pods. |
| **Use `kubectl port-forward` instead of a LoadBalancer** | A public LoadBalancer has a monthly fee. Port-forwarding is free and sufficient for demos. |
| **Delete the entire cluster after demos** | Run `gcloud container clusters delete neurocompass-cluster` to remove all resources. |
| **Monitor spend in the GCP console** | Set a billing alert at $20 so you receive an email before costs escalate. |

---

## 📁 Project Structure

```
goldenticket/
├── README.md                  ← You are here — project overview and quick start
├── CONTRIBUTING.md            ← How to extend or contribute to this project
│
├── scripts/
│   ├── setup_gke.sh           ← Creates the GKE cluster and GPU node pool
│   ├── deploy_nim.sh          ← Deploys NVIDIA NIM via Helm onto the cluster
│   └── process_data.py        ← GPU-accelerated data pipeline (cuDF + UVM)
│
├── frontend/
│   └── index.html             ← Browser chat UI with loading states and error handling
│
└── docs/
    ├── architecture.md        ← Deeper technical explanation of every component
    ├── glossary.md            ← Definitions for GPU VRAM, UVM, TensorRT, and more
    └── demo_script.md         ← 2-minute pitch script for presenting to judges
```

---

## 📖 Further Reading

- [docs/architecture.md](docs/architecture.md) — Technical deep-dive into each component
- [docs/glossary.md](docs/glossary.md) — Plain-English definitions of every technical term used
- [docs/demo_script.md](docs/demo_script.md) — How to present this project in two minutes
- [CONTRIBUTING.md](CONTRIBUTING.md) — How to extend or improve this project

---

## 🏆 About This Project

NeuroCompass was built as a Golden Ticket submission demonstrating enterprise-grade AI infrastructure applied to a human-centered use case: detecting behavioral drift and surfacing structured guidance. Every technology choice reflects a real production constraint, not a tutorial default. The goal is to show that GPU acceleration, Kubernetes, and large language models are not research luxuries — they are engineering tools that can be applied thoughtfully to problems that matter.
