# GitOps Demo Application

A containerized Nginx application designed specifically to demonstrate GitOps principles and workflows. This application serves as the deployment target for the [GitOps-Infra](https://github.com/ThorntonCloud/GitOps-Infra) repository, which contains Kustomize configurations and ArgoCD applications.

## 🎯 Purpose

This repository contains the **application code** for a GitOps demonstration. The actual deployment manifests, Kustomize overlays, and ArgoCD configurations live in the separate **[GitOps-Infra](https://github.com/ThorntonCloud/GitOps-Infra)** repository, following GitOps best practices of separating application source from deployment configuration.

> **Note:** This container is optimized for Kubernetes deployment and may not run properly in local Docker environments due to its security-hardened configuration (non-root user, specific volume mounts, etc.). For local development, use something like [kind](https://kind.sigs.k8s.io).

## 🏗️ Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci-build-push.yaml    # CI: Build and push images on merge to main
│       └── promote-image.yaml    # CD: Promote images to staging/prod
├── nginx-app/
│   ├── Dockerfile                # Container image definition with GitOps metadata
│   └── nginx.conf                # Nginx configuration with observability features
└── README.md
```

## 🔧 Container Configuration

### Dockerfile

The Dockerfile demonstrates several GitOps and cloud-native best practices:

```dockerfile
FROM cgr.dev/chainguard/nginx
```
- Uses **Chainguard's distroless Nginx image** for minimal CVE exposure
- Provides automatic SBOMs (Software Bill of Materials)
- Significantly smaller attack surface than traditional images

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/ThorntonCloud/GitOps-App"
LABEL org.opencontainers.image.description="GitOps-managed Nginx for demo app"
LABEL org.opencontainers.image.vendor="ThorntonCloud"
```
- **OCI-compliant labels** for container registry metadata
- Enables automatic GitHub Container Registry (GHCR) integration
- Provides image provenance for GitOps tooling

```dockerfile
USER 65532
```
- Runs as **non-root user** (nobody) for security
- Kubernetes-friendly security context

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ "/usr/bin/wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health" ]
```
- Built-in **health monitoring** for container orchestrators
- Integrates with Kubernetes liveness/readiness probes

```dockerfile
EXPOSE 8080
```
- Uses **non-privileged port** (no root required)

### Nginx Configuration

The `nginx.conf` includes several features for GitOps observability and monitoring:

#### Key Features

**JSON-Formatted Logging**
```nginx
log_format json_combined escape=json
```
- Structured logs for easy ingestion by log aggregation systems
- Includes request timing, status codes, and user agent information
- Sent to stdout for Kubernetes log collection

**Security Headers**
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```
- OWASP-recommended security headers
- Demonstrates security best practices

**GitOps Identification**
```nginx
add_header X-GitOps-Demo "true" always;
```
- Custom header for easy identification in GitOps environments

**Non-Root Compatibility**
```nginx
pid /tmp/nginx.pid;
```
- PID file in writable location for non-root user

#### Endpoints

| Endpoint | Purpose | Use Case |
|----------|---------|----------|
| `/` | Main application | Serves static content |
| `/health` | Health check | Kubernetes liveness/readiness probes |
| `/metrics` | Metrics stub | Prometheus monitoring integration |

## 🚀 GitOps Workflow

This application follows the **pull-based GitOps model** with a **two-repository pattern** and **manual promotion gates**:

```
┌─────────────────────┐
│   GitOps-App        │  ← Application Source (this repo)
│   (This Repo)       │     • Dockerfile
│                     │     • nginx.conf
└──────────┬──────────┘     • CI/CD workflows
           │
           │ 1. Push to main triggers CI
           │
           ▼
┌─────────────────────┐
│  CI Build & Push    │  ← ci-build-push.yaml
│                     │     • Builds image
│                     │     • Tags with git SHA
└──────────┬──────────┘     • Scans for vulnerabilities
           │
           │ 2. Image pushed to registry
           │
           ▼
┌─────────────────────┐
│  Docker Hub         │  ← thorntoncloud/nginx-gitops:abc1234
│  (Image Registry)   │     thorntoncloud/nginx-gitops:latest
└──────────┬──────────┘
           │
           │ 3. Manual promotion to staging/prod
           │
           ▼
┌─────────────────────┐
│  Promote Image      │  ← promote-image.yaml
│                     │     • Validates source image
│                     │     • Requires approval (prod)
└──────────┬──────────┘     • Retags image (staging/v1.0.0)
           │
           │ 4. Image reference updated
           │
           ▼
┌─────────────────────┐
│   GitOps-Infra      │  ← Deployment Configuration
│                     │     • Kustomize overlays
│                     │     • ArgoCD applications
└──────────┬──────────┘     • Environment-specific configs
           │
           │ 5. ArgoCD syncs
           │
           ▼
┌─────────────────────┐
│   Kubernetes        │  ← Running Application
│   Cluster           │     staging or prod namespace
└─────────────────────┘
```

### The Two-Repo Pattern

**GitOps-App (This Repository):**
- Contains application source code
- Defines the container image
- CI/CD workflows for building and promoting images
- Managed by application developers
- Changes trigger image builds

**GitOps-Infra (Separate Repository):**
- Contains Kubernetes manifests
- Defines deployment topology using Kustomize
- ArgoCD Application definitions
- Managed by platform/ops team
- ArgoCD monitors this repo for changes

This separation follows GitOps principles by decoupling:
- **What** runs (application code) ← This repo
- **Where** and **how** it runs (deployment configuration) ← GitOps-Infra repo

## 📊 Observability Features

### Health Monitoring

The `/health` endpoint provides a simple health check:

```bash
GET /health
HTTP/1.1 200 OK
Content-Type: text/plain

healthy
```

Used by Kubernetes probes:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /health
    port: 8080
```

### Metrics

The `/metrics` endpoint provides a Prometheus-compatible stub:

```
# HELP nginx_up Nginx is running
# TYPE nginx_up gauge
nginx_up 1
```

In production, extend this with nginx-prometheus-exporter for detailed metrics.

### Structured Logging

Access logs are output in JSON format to stdout:

```json
{
  "time": "2025-10-08T12:00:00+00:00",
  "remote_addr": "10.244.0.5",
  "request_method": "GET",
  "request_uri": "/",
  "status": 200,
  "body_bytes_sent": 1234,
  "request_time": 0.001,
  "http_referrer": "",
  "http_user_agent": "kube-probe/1.28"
}
```

These logs integrate seamlessly with:
- Grafana Loki
- ELK Stack
- CloudWatch Container Insights
- Datadog

## 🔐 Security Features

1. **Distroless Base Image**: Chainguard images have 80-90% fewer CVEs
2. **Non-Root Execution**: Runs as UID 65532
3. **Minimal Attack Surface**: No shell, package manager, or unnecessary tools
4. **Security Headers**: OWASP recommended headers enabled
5. **Non-Privileged Port**: Uses port 8080 instead of 80

## 🔄 CI/CD Workflows

This repository implements a **two-stage GitOps promotion model** with automated CI and manual promotion gates for production safety.

### Workflow 1: CI - Build and Push (`ci-build-push.yaml`)

**Trigger:** Automatic on push to `main` branch

**Purpose:** Builds and publishes container images with security scanning

**Steps:**
1. **Build**: Creates Docker image from `nginx-app/` directory
2. **Tag**: Tags image with git short SHA (e.g., `abc1234`) and `latest`
3. **Security Scan**: Runs Trivy vulnerability scanner
   - Outputs results to GitHub Security tab (SARIF format)
   - Checks for CRITICAL and HIGH severity vulnerabilities
4. **Push**: Publishes to Docker Hub at `thorntoncloud/nginx-gitops`

**Example Output:**
```
thorntoncloud/nginx-gitops:abc1234
thorntoncloud/nginx-gitops:latest
```

**Security Features:**
- Trivy scanning integrated into CI pipeline
- SARIF results uploaded to GitHub Security Dashboard
- Build fails on critical vulnerabilities (configurable)
- Automated dependency scanning with every commit

### Workflow 2: Promote Image (`promote-image.yaml`)

**Trigger:** Manual workflow dispatch (human approval required)

**Purpose:** Promotes tested images to staging or production environments

**Required Inputs:**
- `source_sha`: Git SHA of the image to promote (e.g., `abc1234`)
- `target_tag`: Desired tag for promoted image (e.g., `staging`, `v1.0.0`)
- `environment`: Target environment (`staging` or `prod`)

**Validation Rules:**
- Production deployments **must** use semantic versioning (e.g., `v1.0.0`, `v2.1.3`)
- Staging deployments typically use the `staging` tag
- Source image must exist in registry before promotion
- Pre-promotion security scan must pass

**Steps:**
1. **Validate Source**: Verifies the source image exists and is pullable
2. **Security Scan**: Runs comprehensive Trivy scan on source image
3. **Pre-Promotion Test**: Runs basic container health check
4. **Environment Gate**: Requires manual approval for production deployments
5. **Tag & Push**: Retags source image with target tag and pushes to registry
6. **Summary**: Generates deployment summary with next steps

**Example Usage:**

Promote to staging:
```bash
# Via GitHub UI: Actions → Promote Image → Run workflow
Source SHA: abc1234
Target Tag: staging
Environment: staging
```

Promote to production:
```bash
# Via GitHub UI: Actions → Promote Image → Run workflow
Source SHA: abc1234
Target Tag: v1.2.0
Environment: prod
```

### Image Promotion Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Developer pushes to main                                    │
└───────────────┬─────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  CI Workflow (ci-build-push.yaml)                           │
│  • Builds image                                              │
│  • Tags with git SHA (e.g., abc1234)                        │
│  • Runs Trivy security scan                                  │
│  • Pushes to Docker Hub                                      │
└───────────────┬─────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Image Available: thorntoncloud/nginx-gitops:abc1234        │
└───────────────┬─────────────────────────────────────────────┘
                │
                │ Manual testing in dev/local environments
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Promote to Staging (promote-image.yaml)                    │
│  • Validates source image                                    │
│  • Security scan                                             │
│  • Retags as 'staging'                                       │
│  • ArgoCD syncs to staging cluster                          │
└───────────────┬─────────────────────────────────────────────┘
                │
                │ QA testing in staging
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Promote to Production (promote-image.yaml)                 │
│  • Requires production environment approval                  │
│  • Validates semantic versioning (v1.0.0)                   │
│  • Security scan                                             │
│  • Retags with version tag                                   │
│  • ArgoCD syncs to production cluster                       │
└─────────────────────────────────────────────────────────────┘
```

### Security & Compliance

**Trivy Scanning:**
- Scans for vulnerabilities in OS packages and application dependencies
- SARIF output integrated with GitHub Security Dashboard
- Configurable severity thresholds (CRITICAL, HIGH)
- Runs on both CI builds and promotions

**Environment Protection:**
- `staging` environment: Automatic deployment after validation
- `prod` environment: Requires manual approval in GitHub
- Semantic versioning enforced for production releases
- Pre-promotion testing prevents broken deployments

**Image Immutability:**
- SHA-tagged images are never overwritten
- Promotion creates new tags pointing to existing images
- Rollback-friendly: previous versions remain available
- Audit trail via Git history and Docker Hub tags

## 📚 Related Resources

- **[GitOps-Infra Repository](https://github.com/ThorntonCloud/GitOps-Infra)** - Kustomize configurations and ArgoCD apps
- [Chainguard Images](https://www.chainguard.dev/chainguard-images) - Distroless container images
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/) - GitOps continuous delivery
- [Kustomize Documentation](https://kustomize.io/) - Kubernetes configuration management
- [OpenGitOps Principles](https://opengitops.dev/) - GitOps standards

## 🤝 Contributing

This is a demonstration repository. For actual deployment modifications, see the [GitOps-Infra](https://github.com/ThorntonCloud/GitOps-Infra) repository.

---

**Part of the ThorntonCloud GitOps Demo** | [GitOps-Infra Repository](https://github.com/ThorntonCloud/GitOps-Infra)