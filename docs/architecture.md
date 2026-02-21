# Architecture — Technical Deep Dive

This document provides a layer-by-layer explanation of every component in NeuroCompass. It is intended for engineers who want to understand *why* each technology was chosen and how the pieces connect.

---

## 1. Data Layer — Apache Parquet on Google Cloud Storage

### What is stored and why

Raw behavioral and health data is stored in **Apache Parquet** format inside a Google Cloud Storage (GCS) bucket. Parquet is a columnar binary file format originally developed at Twitter and now maintained as an Apache project.

**Why not CSV?**

A CSV stores data row-by-row. Reading column `sleep_hours` from a 10 million-row CSV requires reading every byte of every row just to get to that column. Parquet stores each column's values contiguously on disk. Reading `sleep_hours` from a 50-column Parquet file reads roughly 1/50th of the data — everything else is skipped at the I/O level.

Additionally, Parquet:
- Encodes data with per-column compression (Snappy or Zstd), typically achieving 3–6× compression over CSV
- Stores column type metadata so no type inference is needed on load
- Supports predicate pushdown: the reader can skip entire row groups if the filter does not match any values in that group

**Why GCS?**

Google Cloud Storage is object storage — durable, cheap, and directly accessible from both Colab Enterprise and GKE. Storing data in GCS decouples the processing compute (Colab) from the serving compute (GKE), so either can be modified independently.

---

## 2. Processing Layer — cuDF + Unified Virtual Memory in Colab Enterprise

### NVIDIA RAPIDS cuDF

cuDF is part of NVIDIA's RAPIDS open-source suite. It implements a pandas-compatible DataFrame API that executes all operations on the GPU using CUDA kernels.

The integration point is the pandas extension API:

```python
%load_ext cudf.pandas
```

After this single line, every subsequent `import pandas as pd` in the notebook is redirected to cuDF. The code looks identical to standard pandas, but operations execute on the GPU.

**Performance characteristics:**

| Operation | pandas (CPU, 10M rows) | cuDF (A100 GPU) | Speedup |
|---|---|---|---|
| `groupby().mean()` | ~45s | ~0.4s | ~112× |
| `merge()` | ~30s | ~0.3s | ~100× |
| `apply()` (UDF) | ~60s | variable | varies |

Note: `apply()` with Python lambdas falls back to CPU. cuDF accelerates vectorised operations only.

### Unified Virtual Memory

The GPU has dedicated VRAM (Video RAM) physically soldered to the PCIe card. A standard GPU allocation raises `cudf.MemoryError` if the allocation exceeds available VRAM.

UVM (Unified Virtual Memory) is a CUDA feature that places allocations in a shared address space accessible from both the GPU and CPU. When the GPU tries to access a UVM page that currently lives in CPU RAM, the CUDA driver pages it in transparently — no application code change required.

```python
import rmm
rmm.mr.set_current_device_resource(rmm.mr.CudaManagedMemoryResource())
```

This line replaces the default allocator with a UVM-backed one. All subsequent cuDF allocations use UVM pages. The trade-off is that inter-device page migration has latency (~2 µs per page fault), so UVM is slower than pure VRAM when the working set fits in VRAM. For datasets that exceed VRAM, UVM is the difference between a program that works and one that crashes.

---

## 3. Orchestration Layer — Google Kubernetes Engine (GKE)

### What Kubernetes does

Kubernetes is a container orchestration system. It manages the lifecycle of containers across a cluster of machines:

- **Scheduling:** places containers on machines that have sufficient CPU, RAM, and GPU resources
- **Self-healing:** restarts containers that crash; replaces nodes that fail
- **Scaling:** adds or removes container replicas based on load
- **Networking:** assigns each pod a virtual IP and manages internal DNS

GKE is Google's managed Kubernetes service. Google manages the control plane (the API server, scheduler, and etcd database). You manage the node pools (the worker machines).

### Cluster design

```
GKE Cluster: neurocompass-cluster
├── Default node pool (n1-standard-2, 1 node)
│   └── System pods: kube-dns, metrics-server, node driver installer
└── GPU node pool: gpu-pool (g2-standard-4, 0–1 nodes, auto-scaling)
    └── NIM pod: nim-llm (requests 1× nvidia.com/gpu)
```

Separating the GPU node pool allows it to scale to zero when no GPU pods are scheduled. This is the primary cost-saving measure — a GKE control plane costs ~$0.10/hour; the GPU node costs ~$0.70/hour. When no demo is running, only the control plane charge applies.

### GPU node scheduling

Kubernetes uses resource requests to schedule pods. The NIM Helm chart sets:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

The Kubernetes scheduler only places this pod on a node that has an unclaimed `nvidia.com/gpu` resource, which is only nodes in `gpu-pool`. The GPU device plugin (installed via DaemonSet during setup) advertises the physical GPU to Kubernetes.

---

## 4. Inference Layer — NVIDIA NIM

### What NIM does

NVIDIA NIM is a pre-packaged inference server that:

1. **Pulls model weights** from NVIDIA's NGC registry on first start (requires NGC API key)
2. **Compiles with TensorRT** — TensorRT analyses the model graph, fuses operations, quantises weights where safe, and generates optimised CUDA kernels for the specific GPU type detected at runtime
3. **Caches the compiled engine** on the persistent volume so subsequent restarts skip recompilation (~10 minutes saved)
4. **Serves an OpenAI-compatible REST API** (`/v1/chat/completions`) so any code written for OpenAI works without modification

### TensorRT optimisation details

TensorRT performs several transformations:

| Optimisation | Effect |
|---|---|
| Layer fusion | Combines adjacent layers (e.g., matmul + bias + activation) into one CUDA kernel, reducing memory round-trips |
| Precision calibration | Converts FP32 weights to FP16 or INT8 where the accuracy drop is acceptable, roughly doubling throughput |
| Kernel auto-tuning | Benchmarks multiple CUDA kernel implementations and selects the fastest for the target GPU |
| Graph compilation | Eliminates Python overhead — the entire inference graph becomes a single compiled engine |

For Llama 3 8B on an NVIDIA L4, TensorRT typically delivers ~2× the tokens-per-second compared to an unoptimised HuggingFace `pipeline()`.

### API compatibility

NIM exposes the same endpoint shape as OpenAI:

```
POST http://localhost:8000/v1/chat/completions
{
  "model": "meta/llama3-8b-instruct",
  "messages": [...],
  "max_tokens": 300
}
```

This compatibility means any tool, library, or frontend built for OpenAI (LangChain, the OpenAI Python SDK, the JavaScript fetch example in `frontend/index.html`) works without modification.

---

## 5. Frontend Layer — `frontend/index.html`

The frontend is a single HTML file with no build tools or npm dependencies. This is an intentional choice for a portfolio demo: it can be opened directly in a browser with no setup, demonstrated from any laptop, and understood by anyone who knows basic HTML and JavaScript.

Key implementation details:

- **Conversation history management:** The OpenAI API is stateless — each request must include the full conversation history. The frontend maintains an array of `{ role, content }` objects and appends to it on every turn.
- **Connection health check:** On page load, the frontend pings `/v1/models`. This tells the user immediately whether `kubectl port-forward` is running rather than letting them send a message into a void.
- **Graceful degradation:** Every network error path produces a specific, actionable message (e.g., "run kubectl port-forward") rather than a generic "something went wrong".
- **Accessible markup:** The message list uses `role="log"` and `aria-live="polite"` so screen readers announce new messages.

---

## Data Flow Summary

```
User types message
      │
      ▼
frontend/index.html (browser)
  POST /v1/chat/completions
  body: { model, messages: [system, ...history, user] }
      │
      ▼ (localhost:8000 via kubectl port-forward)
      │
      ▼
NIM Pod (Kubernetes, GPU node)
  TensorRT-compiled Llama 3 8B
  GPU inference (~0.5–2s for 300 tokens on L4)
      │
      ▼
JSON response: { choices: [{ message: { content: "..." } }] }
      │
      ▼
frontend appends assistant message bubble
```
