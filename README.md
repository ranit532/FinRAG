## FinRAG POC

End-to-end Retrieval Augmented Generation (RAG) proof of concept for a global insurance organization. The stack combines a FastAPI backend, React/Vite frontend, Pinecone vector search, and Azure-managed services deployed through Terraform and released via Azure DevOps.

### Architecture Highlights

```mermaid
sequenceDiagram
    participant User as User / Broker
    participant FE as React Frontend<br/>(Azure Static Web)
    participant API as FastAPI Backend<br/>(Azure App Service)
    participant AOAI as Azure OpenAI<br/>(gpt-4o-mini + embeddings)
    participant PC as Pinecone<br/>(Vector Index)

    rect rgb(240,240,255)
      Note over User,PC: Online Query Flow
      User->>FE: Ask question about premiums / loss ratios
      FE->>API: POST /api/rag/query { question }
      API->>AOAI: Generate embedding for question
      AOAI-->>API: Embedding vector
      API->>PC: Query top-k similar chunks
      PC-->>API: Matching chunks + metadata
      API->>AOAI: Call chat model with context + question
      AOAI-->>API: Grounded answer text
      API-->>FE: { answer, references }
      FE-->>User: Render answer & source snippets
    end

    rect rgb(235,255,235)
      Note over API,PC: Offline Ingestion (scripts/app.ingest.py)
      API->>API: Run Seeder().ingest()
      API->>API: Load synthetic_policies.json
      API->>AOAI: Embed each document chunk
      AOAI-->>API: Embedding vectors
      API->>PC: Upsert vectors + metadata
      PC-->>API: Index updated
    end
```

- **Frontend**: React + Vite single-page app served from Azure Storage static website fronted by Azure CDN (optional) with MSAL hooks for corporate SSO.
- **Backend**: FastAPI hosted on Azure App Service (Linux). Uses managed identity to call Azure OpenAI and securely obtains Pinecone credentials from Key Vault (stubbed for PoC).
- **LLM & Retrieval**: Azure OpenAI `gpt-4o-mini` for responses and `text-embedding-3-large` for vectorization. Pinecone hosts insurance document embeddings.
- **Data Plane**: Placeholder ingestion script chunks synthetic transactional docs and upserts embeddings into Pinecone.
- **IaC**: Terraform config under `infra/terraform` provisions the RG, OpenAI, storage, App Service, App Insights, Log Analytics, and an Azure DevOps service connection.
- **CI/CD**: `devops/azure-pipelines.yml` defines build, infrastructure, and deployment stages with manual approval gates.

### Repository Layout
- `frontend/` – React UI (Vite, TypeScript) with a `RagChat` component calling the backend.
- `backend/` – FastAPI app (`app/main.py`) plus `rag_pipeline.py` orchestrating Azure OpenAI + Pinecone, and `ingest.py` for data loading.
- `data/` – `synthetic_policies.json` sample dataset for PoC ingestion.
- `infra/terraform/` – Terraform modules for Azure + Azure DevOps resources.
- `devops/azure-pipelines.yml` – Multi-stage Azure DevOps YAML pipeline.

### Azure Services Used

| Service | Logo | Purpose in this PoC |
|--------|------|---------------------|
| **Azure Resource Group** | ![Azure Resource Group](docs/assets/azure-logos/azure-resource-group.svg) | Logical container for all Azure resources (compute, storage, observability, OpenAI). |
| **Azure Storage (Static Website)** | ![Azure Storage](docs/assets/azure-logos/azure-storage.svg) | Hosts the built React/Vite frontend as a static site in the `$web` container. |
| **Azure App Service (Linux)** | ![Azure App Service](docs/assets/azure-logos/azure-app-service.svg) | Runs the FastAPI backend with a Linux App Service Plan, exposing the `/api/rag/query` endpoint. |
| **Managed Identity (System-assigned)** | ![Managed Identity](docs/assets/azure-logos/managed-identity.svg) | Allows the backend to authenticate to Azure OpenAI without storing keys or secrets. |
| **Azure OpenAI (Cognitive Services)** | ![Azure OpenAI](docs/assets/azure-logos/azure-openai.svg) | Provides `gpt-4o-mini` for answers and `text-embedding-3-large` for vector embeddings. |
| **Log Analytics Workspace** | ![Log Analytics](docs/assets/azure-logos/log-analytics.svg) | Central store for logs and metrics collected from Application Insights. |
| **Application Insights** | ![Application Insights](docs/assets/azure-logos/application-insights.svg) | Observability for the backend (APM, traces, availability). |
| **Azure AD / Entra ID (App + SP)** | ![Azure AD](docs/assets/azure-logos/azure-ad.svg) | App registration + service principal used by Azure DevOps service connection. |
| **Azure DevOps (Project + Pipelines)** | ![Azure DevOps](docs/assets/azure-logos/azure-devops.svg) | Hosts the Git repo, YAML pipelines, and the Azure service connection used to run Terraform and deploy the app. |

> **Note**: The logo files are stored under `docs/assets/azure-logos`. They are placeholders in this PoC; replace them with the official Azure SVG icons from Microsoft’s `azure-icons` repository (or your internal design system) to show the real product logos.

### Local Development
1. **Frontend**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```
   Configure `VITE_API_BASE_URL` in `.env` to point at the FastAPI URL.

2. **Backend**
   ```bash
   cd backend
   python -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   uvicorn app.main:app --reload
   ```
   Export Azure OpenAI & Pinecone env vars or load via `.env`.

3. **Data Ingestion**
   ```bash
   cd backend
   python -m app.ingest
   ```
   Populates Pinecone with sample documents from `data/synthetic_policies.json`.

### Terraform Deployment
1. Copy `infra/terraform/terraform.tfvars.example` ➜ `terraform.tfvars` and fill values (region, DevOps org/project, PAT, etc.).
2. **For free-credit PoC usage**, the Terraform defaults aim to fit new-subscription quotas:
   - App Service Plan uses `S1` (first paid tier commonly available even when Free/Basic quotas = 0). If your subscription still shows zero Standard quota, request a quota increase or switch to a region/subscription with available App Service compute before applying Terraform.
   - Log Analytics retention is set to 30 days (minimum allowed for PerGB2018).
   - Azure OpenAI uses widely-available models (`gpt-35-turbo`, `text-embedding-ada-002`) at `S0` scale; keep prompts light during experimentation.
   - Storage account names auto-sanitize to meet Azure constraints.
   - Cognitive deployments set the default Responsible AI policy so new regions accept the deployment request.
   - You can skip creating the Azure DevOps project by leaving `create_azure_devops_project = false` (default) and Terraform will re-use an existing project instead.
3. Configure AzureRM backend (remote state) or let Terraform default to local.
4. Run:
   ```bash
   cd infra/terraform
   terraform init
   terraform plan
   terraform apply
   ```
5. Outputs expose the App Service URL, static site endpoint, and OpenAI endpoint for connecting the app.

### Azure DevOps Pipeline
1. Import this repo into your Azure DevOps project or connect via service connection.
2. Create secret variables referenced in `devops/azure-pipelines.yml` (e.g., `FINRAG_SERVICE_CONNECTION`, `WEBAPP_NAME`, `STORAGE_ACCOUNT`, TF backend settings).
3. Queue the pipeline:
   - **BuildTest stage**: lint/tests for backend, build for frontend.
   - **DeployInfra**: Installs Terraform, runs plan, waits for manual approval, then applies.
   - **DeployApp**: Packages backend to zip > deploy to App Service, uploads frontend assets to Storage static site.

### Security Notes
- FastAPI App Service runs with system-assigned managed identity; Terraform grants `Cognitive Services OpenAI User` role.
- Azure DevOps gets its own Azure AD service principal; Terraform mints a 1-year credential and wires it into the service connection automatically.
- Pinecone API key injected via Key Vault (to be wired in production); `.env` usage here is for local testing only.

### Next Steps
- Integrate Azure API Management or Front Door for zero-trust ingress.
- Replace static dataset with ingestion from Azure Storage or Cosmos DB plus Azure Functions event triggers.
- Add integration tests validating retrieval-grounded answers using contract tests in CI/CD.

### High-Level Architecture Diagram

```mermaid
flowchart LR
    subgraph Azure
      A["User Browser"] --> B["Azure Storage Static Website - React/Vite Frontend"]
      B -->|HTTPS JSON| C["Azure App Service Linux - FastAPI + Managed Identity"]

      subgraph AzureOpenAI["Azure OpenAI"]
        D1["gpt-4o-mini - Chat/Completion"]
        D2["text-embedding-3-large - Embedding"]
      end

      C -->|Managed Identity AAD| AzureOpenAI

      subgraph Observability
        E["Log Analytics Workspace"]
        F["Application Insights"]
      end

      C --> F
      F --> E
    end

    C -->|HTTPS API key| G["Pinecone Vector Index"]

    subgraph AzureDevOps["Azure DevOps"]
      H["Azure DevOps Project - Repos and Pipelines"]
      I["Azure Service Connection - SPN"]
    end

    H -->|CI/CD Pipelines| C
    H -->|Static Build Artifacts| B
    H -->|Terraform Plan Apply| Azure
```