# Demo Script — 2-Minute Pitch

Use this script when presenting NeuroCompass to judges, interviewers, or technical audiences. The total runtime is approximately 2 minutes. Adjust the emphasis based on whether your audience is technical or non-technical.

---

## The Script

**[OPEN — 15 seconds]**

"Most AI demos show you a chatbot. This shows you the entire stack behind it — from raw data on cloud storage, through a GPU cluster, to a response in the browser — and explains every choice along the way."

---

**[THE PROBLEM — 20 seconds]**

"Behavioral drift is the gradual, unnoticed erosion of daily routines — sleep, energy, focus. It often precedes burnout or cognitive decline, but it is hard to detect because the changes are slow.

NeuroCompass processes large behavioral datasets and routes structured questions to a language model that identifies these patterns and suggests corrective actions."

---

**[PHASE 1 — Data Processing, 25 seconds]**

"The dataset lives in Google Cloud Storage as Parquet files — a columnar format that is 50× faster to query than CSV at this scale.

Processing runs on Colab Enterprise using cuDF, which is a drop-in GPU replacement for pandas. One line of code activates it. A 10-million-row aggregation that takes 45 seconds on CPU takes 0.4 seconds on the GPU.

Unified Virtual Memory is enabled so datasets larger than GPU VRAM spill to CPU RAM automatically instead of crashing."

---

**[PHASE 2 — Model Serving, 25 seconds]**

"The model runs on a Kubernetes cluster on Google Cloud — two shell scripts create the cluster, provision a GPU node pool, and deploy the model via Helm.

NVIDIA NIM handles the model server. It downloads Llama 3, compiles it with TensorRT for the specific GPU in the node, and exposes an OpenAI-compatible API endpoint. I did not write a single line of model serving code — I chose the right tool.

The GPU node auto-scales to zero when the demo is not running, so I am not paying for idle hardware."

---

**[PHASE 3 — Integration, 15 seconds]**

"The frontend is a single HTML file — no frameworks, no build tools. It connects to the NIM endpoint through a Kubernetes port-forward tunnel.

It shows connection status, loading indicators, and friendly error messages that tell you exactly what to do when something goes wrong."

---

**[CLOSE — 20 seconds]**

"What I want you to take away is not the individual technologies — it is the systems thinking.

Every choice has a reason: Parquet for I/O efficiency, UVM for memory safety, a GPU node pool for cost control, NIM instead of a custom server.

This project demonstrates that I can design, deploy, and explain production AI infrastructure — and I can do it in a way that is accessible to engineers at every level."

---

## Tips for Delivery

- **For a technical audience:** Pause after Phase 1 and Phase 2 to take questions. Engineers often want to dig into the UVM implementation or the TensorRT compilation step.

- **For a non-technical audience:** Skip the command names (cuDF, TensorRT, kubectl). Focus on the problem (behavioral drift), the outcome (the chat interface), and the key idea (GPU acceleration = real-time analysis of huge datasets).

- **For a live demo:** Have `kubectl port-forward service/nim-llm 8000:8000` already running and `frontend/index.html` open in the browser before you start. Send this example prompt: *"I have been sleeping 4 hours a night for two weeks and my focus is gone. What is happening?"*

- **If asked about cost:** "A single GPU node is about $0.70/hour. I auto-scale to zero. The whole demo costs under $5 to run from scratch." Reference the Cost Awareness section in the README.

- **If asked why not use a managed endpoint (e.g., Vertex AI):** "I wanted to show the full infrastructure layer — Kubernetes, GPU scheduling, Helm, container credentials. A managed endpoint hides that complexity, which is the right choice in production, but the wrong choice for a portfolio that is supposed to demonstrate that I understand the stack."

---

## Q&A Preparation

| Question | Short answer |
|---|---|
| Why Llama 3 and not GPT-4? | Llama 3 runs on my own GPU cluster — I own the inference, the latency, and the cost. GPT-4 is a black box with a per-token bill. |
| How long does the first deployment take? | ~15 minutes: 5 min for cluster creation, 10 min for NIM to download and compile the model. |
| Is the data real? | The processing script is built for real data. The demo uses synthetic data to avoid any PII concerns. |
| Why a single HTML file instead of React? | The goal was to demonstrate AI infrastructure, not frontend engineering. A single file minimises setup friction and lets any judge run the demo immediately. |
| What would you add with more time? | A streaming response API (Llama 3 supports Server-Sent Events), a PostgreSQL backend to store conversation history, and a Grafana dashboard showing GPU utilisation and token throughput. |
