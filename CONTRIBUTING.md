# Contributing to NeuroCompass

Thank you for your interest in extending this project. This guide explains how the codebase is organised, which parts are easiest to modify, and several concrete ideas for improvements.

---

## Getting Started

1. Fork the repository on GitHub.
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/goldenticket.git
   cd goldenticket
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. Make your changes, test them, and open a pull request against `main`.

There are no automated tests currently, so include a short description in your PR of what you changed and how you verified it works.

---

## Project Structure

```
goldenticket/
├── README.md              ← Project overview (update if your change is user-facing)
├── CONTRIBUTING.md        ← This file
├── scripts/
│   ├── setup_gke.sh       ← Infrastructure provisioning
│   ├── deploy_nim.sh      ← Model deployment
│   └── process_data.py    ← Data pipeline
├── frontend/
│   └── index.html         ← Browser chat interface
└── docs/
    ├── architecture.md    ← Technical deep-dive
    ├── glossary.md        ← Term definitions
    └── demo_script.md     ← Pitch script
```

---

## Extension Ideas

Each of these ideas adds meaningful technical value and makes a good portfolio contribution.

### 1. Streaming Responses

**What:** Stream tokens from the model as they are generated instead of waiting for the full response.

**Why it matters:** Streaming makes the UI feel faster and is standard behaviour for modern LLM interfaces.

**How to implement:**
- Add `"stream": true` to the fetch request body in `frontend/index.html`.
- Switch from `response.json()` to a `ReadableStream` reader that processes `data: {...}` Server-Sent Events.
- Append each token chunk to the assistant message div as it arrives.
- NIM supports streaming natively — no server-side changes required.

**Difficulty:** ⭐⭐ — moderate. The main challenge is the streaming response parser.

---

### 2. Conversation History Persistence

**What:** Save conversation history to `localStorage` or a backend database so conversations survive page refreshes.

**Why it matters:** Demonstrates state management and persistence, which are required in any real application.

**How to implement (localStorage, no backend):**
```javascript
// After appending a message, save the history
localStorage.setItem("conversationHistory", JSON.stringify(conversationHistory));

// On page load, restore it
const saved = localStorage.getItem("conversationHistory");
if (saved) conversationHistory = JSON.parse(saved);
```

**How to implement (backend):**
- Add a simple FastAPI or Express server that stores messages in SQLite or PostgreSQL.
- Update the frontend to POST messages to your backend, which in turn calls NIM.

**Difficulty:** ⭐ (localStorage) or ⭐⭐⭐ (backend)

---

### 3. GPU Utilisation Dashboard

**What:** Add a Grafana dashboard that shows GPU utilisation, memory usage, and NIM token throughput in real time.

**Why it matters:** Production systems require observability. This demonstrates MLOps maturity.

**How to implement:**
- Install the `kube-prometheus-stack` Helm chart:
  ```bash
  helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
  ```
- NVIDIA's DCGM Exporter exposes GPU metrics to Prometheus:
  ```bash
  helm install dcgm-exporter nvidia/dcgm-exporter -n monitoring
  ```
- Import NVIDIA's pre-built Grafana dashboard (ID 12239) for instant GPU visualisation.

**Difficulty:** ⭐⭐⭐ — requires understanding of Prometheus metrics and Kubernetes namespaces.

---

### 4. Swap the Model

**What:** Replace Llama 3 8B with a different NIM-supported model (e.g., Mistral 7B, Llama 3 70B, or a medical-domain fine-tune).

**Why it matters:** Demonstrates understanding of how to change the inference layer without touching the application code.

**How to implement:**
- Browse available NIM models at [catalog.ngc.nvidia.com](https://catalog.ngc.nvidia.com).
- Update the `NIM_MODEL` and `NIM_IMAGE` variables in `scripts/deploy_nim.sh`.
- Update the `model` field in the fetch body in `frontend/index.html`.
- Larger models (70B) require a larger GPU (A100 80GB) — update `MACHINE_TYPE` in `setup_gke.sh`.

**Difficulty:** ⭐ — mostly configuration changes.

---

### 5. Drift Detection Visualisation

**What:** Add a chart in the frontend that visualises the drift score over time from the processed Parquet data.

**Why it matters:** Connects the data pipeline to the UI, completing the full product story.

**How to implement:**
- Add a lightweight charting library (e.g., Chart.js via CDN) to `frontend/index.html`.
- Create a small FastAPI endpoint that reads the processed Parquet file from GCS and returns drift scores as JSON.
- Render a line chart above the chat box showing drift over time, with the current session highlighted.

**Difficulty:** ⭐⭐⭐ — requires a backend API and understanding of the data pipeline output.

---

### 6. Improve the Data Pipeline

**What:** Add more sophisticated feature engineering to `scripts/process_data.py`.

**Ideas:**
- Rolling window statistics (7-day average vs current value)
- Multi-variable drift detection (sleep + activity + heart rate combined)
- Anomaly detection using cuML's `LocalOutlierFactor`
- Write results to BigQuery for long-term storage and SQL queries

**Difficulty:** ⭐⭐ — requires familiarity with pandas/cuDF DataFrame operations.

---

## Code Style

- **Shell scripts:** Follow the conventions already in `setup_gke.sh` and `deploy_nim.sh`. Use `set -euo pipefail`. Add a comment explaining the *why* for every non-obvious command.
- **Python:** PEP 8. Add a docstring to every function. Explain technology choices in comments, not just what the code does.
- **HTML/JavaScript:** Keep `frontend/index.html` self-contained (no npm, no bundler). Add comments for every non-obvious JavaScript pattern.
- **Markdown:** Use headers (`##`, `###`), tables, and code fences. Write for a beginner audience — define terms when you first use them.

---

## Questions

Open a GitHub Issue if you have questions about the architecture, run into problems setting up the environment, or want to discuss a contribution idea before building it.
