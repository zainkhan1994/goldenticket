# Glossary

Plain-English definitions of every technical term used in this project. If you encounter a word in the code or README that you do not recognise, look it up here first.

---

## A

**API (Application Programming Interface)**
A defined contract between two pieces of software. One side says "if you send me a request in this exact format, I will send back a response in this exact format." In this project, NVIDIA NIM exposes an HTTP API — the frontend sends a JSON message to a specific URL, and the model sends back a JSON reply.

**Auto-scaling**
A Kubernetes feature that automatically adds more worker nodes when demand increases and removes them when demand drops. In this project, the GPU node pool scales to zero (0 nodes) when no model pod is running, eliminating GPU charges during idle periods.

---

## C

**CUDA**
Compute Unified Device Architecture — NVIDIA's parallel computing platform that lets programs run code on the GPU. All cuDF and TensorRT operations ultimately compile to CUDA kernels. You do not need to write CUDA yourself to use this project; the libraries handle it.

**cuDF**
NVIDIA's GPU-accelerated DataFrame library, part of the RAPIDS ecosystem. It implements the same API as pandas but executes operations on the GPU, typically 10–100× faster for large datasets. Installed via `pip install cudf-cu12`.

**Container**
A lightweight, portable package that bundles an application together with all its dependencies (libraries, runtime, config files). Containers run consistently on any machine that has a container runtime (Docker or containerd). Kubernetes schedules and manages containers.

**Container Image**
A read-only snapshot of a container's filesystem. Think of it as a ZIP file containing the application and its dependencies. When Kubernetes starts a container, it pulls the image and creates a running instance from it.

---

## D

**DaemonSet**
A Kubernetes resource that runs exactly one copy of a pod on every node in the cluster (or on every node matching a label selector). In this project, NVIDIA's driver installer runs as a DaemonSet — it installs GPU drivers on every GPU node automatically.

**Drift Score**
A custom metric computed in `scripts/process_data.py`. It measures how far a behavioral data point (e.g., sleep hours) deviates from the person's own baseline, expressed as an absolute z-score. A high drift score signals a significant change in routine.

---

## G

**GCS (Google Cloud Storage)**
Google's object storage service. Files (called "objects") are stored in buckets and addressed by `gs://bucket-name/path`. GCS is durable (designed for 99.999999999% annual durability), cheap (~$0.02/GB/month for standard storage), and accessible from anywhere in Google Cloud.

**GKE (Google Kubernetes Engine)**
Google's managed Kubernetes service. Google runs and maintains the Kubernetes control plane (the software that manages the cluster) while you manage the worker nodes (the machines that run your applications). GKE handles Kubernetes upgrades, security patches, and control plane availability.

**gcloud**
The command-line tool for Google Cloud. Used in this project to create clusters, enable APIs, and configure authentication. Equivalent to AWS CLI for AWS or Azure CLI for Azure.

**GPU (Graphics Processing Unit)**
Originally designed for rendering graphics, GPUs have thousands of small cores optimised for parallel arithmetic. This makes them ideal for AI workloads, which are essentially massive matrix multiplications. In this project, the GPU accelerates both data processing (cuDF) and model inference (NIM + TensorRT).

**GPU VRAM (Video RAM)**
The memory physically attached to the GPU chip. It is separate from the computer's main RAM (CPU RAM) and much faster for GPU operations (~900 GB/s bandwidth for an A100 vs ~50 GB/s for CPU DDR5). VRAM is limited — a typical L4 has 24 GB, an A100 has 40–80 GB. When a GPU program tries to allocate more than the available VRAM, it crashes with an Out-of-Memory error unless UVM is enabled.

---

## H

**Helm**
The package manager for Kubernetes. A Helm "chart" is a collection of Kubernetes YAML templates, default values, and metadata. Running `helm install` renders the templates with your values and applies them to the cluster. This is far simpler than writing raw Kubernetes YAML files by hand.

**Helm Chart**
A packaged set of Kubernetes resource definitions for a particular application. NVIDIA publishes a NIM chart at `https://helm.ngc.nvidia.com/nvidia` that handles all the complexity of deploying NIM: pulling credentials, requesting GPU resources, setting up persistent storage, and exposing a service.

---

## I

**Inference**
Running a trained AI model to generate predictions or responses. In this project, inference means sending a text prompt to Llama 3 and receiving a text response. Inference is distinct from training (teaching the model from scratch), which is far more expensive.

---

## K

**kubectl**
The command-line tool for interacting with a Kubernetes cluster. `kubectl get pods` lists running containers; `kubectl logs` streams their output; `kubectl port-forward` creates a tunnel from your laptop to a pod inside the cluster. Equivalent to `docker` for single-container management, but for a whole cluster.

**Kubernetes**
An open-source system for automating the deployment, scaling, and management of containerised applications. Originally developed by Google, now maintained by the Cloud Native Computing Foundation. GKE is the managed version.

**Kubernetes Namespace**
A virtual partition inside a cluster. Resources (pods, services, secrets) in one namespace are isolated from resources in another. In this project, NIM lives in the `nim` namespace to keep it separate from system components in the `kube-system` namespace.

---

## L

**Llama 3**
A family of large language models released by Meta AI. The 8B variant (8 billion parameters) fits comfortably on a single NVIDIA L4 GPU and is capable of nuanced text generation. NIM uses the `meta/llama3-8b-instruct` variant, which is fine-tuned for instruction following and conversation.

**LoadBalancer**
A Kubernetes service type that provisions an external IP address so traffic from the internet can reach pods in the cluster. In this project, we deliberately do *not* use a LoadBalancer (it costs money and exposes the model publicly). Instead, we use `kubectl port-forward`, which is free and only accessible from your local machine.

---

## N

**NGC (NVIDIA GPU Cloud)**
NVIDIA's registry for GPU-optimised software: container images, model weights, Helm charts, and SDKs. You need a free NGC account to pull NIM images and model weights. The API key from your NGC account is stored as a Kubernetes Secret so the NIM pod can authenticate.

**NIM (NVIDIA Inference Microservices)**
A pre-packaged, production-ready inference server from NVIDIA. It downloads a model, compiles it with TensorRT for the specific GPU present at runtime, and exposes an OpenAI-compatible REST API. NIM eliminates the need to write model serving code from scratch.

**Node**
A single machine (virtual or physical) in a Kubernetes cluster. Each node runs a container runtime (containerd) and the Kubernetes node agent (kubelet). GPU nodes have an NVIDIA GPU attached and advertise it to the Kubernetes scheduler via the device plugin.

**Node Pool**
A group of nodes in a GKE cluster that share the same machine type and configuration. This project uses two node pools: a default CPU pool for system components and a GPU pool for NIM. The GPU pool can be independently scaled or deleted without affecting the rest of the cluster.

---

## O

**OpenAI API**
The REST API interface popularised by OpenAI for interacting with language models. The request format (`POST /v1/chat/completions` with a `messages` array) has become an industry standard. NIM implements the same format, so any code written for OpenAI GPT-4 works with NIM without changes.

---

## P

**Parquet**
A columnar binary file format for structured data. Parquet stores each column's values together on disk, enabling analytics queries to read only the needed columns and skip the rest. Parquet also applies per-column compression and stores schema metadata, making it far more efficient than CSV for large datasets. See `docs/architecture.md` for benchmark comparisons.

**Persistent Volume (PV)**
Storage in Kubernetes that outlives the pod that uses it. When NIM compiles the model with TensorRT, the compiled engine is saved to a persistent volume. If the pod restarts, NIM loads the engine from the volume instead of recompiling, saving ~10 minutes.

**Pod**
The smallest deployable unit in Kubernetes. A pod contains one or more containers that share a network namespace (same IP) and can share volumes. In this project, one pod runs the NIM container.

**Port Forward**
A `kubectl` command that creates a secure tunnel from a port on your local machine to a port inside a pod. Running `kubectl port-forward service/nim-llm 8000:8000` makes `http://localhost:8000` on your laptop reach the NIM service inside the cluster. No public IP, no firewall rules, no cost.

---

## R

**RAPIDS**
A suite of open-source GPU-accelerated data science libraries from NVIDIA. The key library in this project is cuDF (GPU DataFrames). Other RAPIDS libraries include cuML (GPU machine learning), cuGraph (GPU graph analytics), and RMM (RAPIDS Memory Manager).

**RMM (RAPIDS Memory Manager)**
The memory management layer for all RAPIDS libraries. RMM supports multiple memory resources (device memory, pinned host memory, managed/UVM memory, pool allocators). In this project, `rmm.mr.CudaManagedMemoryResource()` enables UVM for all cuDF allocations.

---

## T

**TensorRT**
NVIDIA's inference optimisation compiler. TensorRT takes a model in a standard format (ONNX, PyTorch), analyses its computation graph, and generates a "compiled engine" — a set of highly optimised CUDA kernels tailored to the specific GPU present. Key optimisations include layer fusion, precision reduction (FP16/INT8), and kernel auto-tuning. NIM runs TensorRT automatically; you do not call it directly.

**Token**
The unit of text that language models work with. A token is roughly 4 characters or ¾ of a word in English. "Hello world" is 2 tokens. "neuroscience" is 3 tokens. `max_tokens: 300` in the frontend limits each response to roughly 225 words.

---

## U

**UVM (Unified Virtual Memory)**
A CUDA memory management feature that maps GPU and CPU memory into a single shared address space. When a GPU kernel accesses a UVM page currently resident in CPU RAM, the CUDA driver migrates it to GPU memory (a "page fault"). This allows GPU programs to use datasets larger than GPU VRAM without manual memory management. The trade-off is that page faults add latency; pure VRAM access is always faster.

---

## Z

**Z-score**
A statistical measure of how many standard deviations a value is from the mean. Formula: `(value - mean) / standard_deviation`. Used in `process_data.py` to compute the drift score. A z-score of 0 means the value is exactly at the average. A z-score of 2 means the value is 2 standard deviations above average — uncommon but not extreme. A z-score above 3 is considered an outlier in most domains.
