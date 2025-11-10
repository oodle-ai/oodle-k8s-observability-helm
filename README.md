# Oodle Kubernetes Observability Helm Chart

An umbrella Helm chart that provides a complete observability stack for Kubernetes clusters, including metrics, logs, and events collection.

## Overview

This chart deploys:

- **kube-state-metrics** - Kubernetes object state metrics
- **prometheus-node-exporter** - Node-level hardware and OS metrics
- **vmagent** - Prometheus metrics collection and remote write to Oodle
- **oodle-k8s-auto-instrumentation** - eBPF-based auto-instrumentation using Beyla
- **vector-agent & vector-aggregator** - Log collection and processing pipeline
- **kubernetes-event-exporter** - Kubernetes events collection

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- Oodle endpoint and API key


## Installation

### Install from Repository

```bash
# Add Helm repository
helm repo add oodle https://oodle-ai.github.io/helm-charts
helm repo update

# Install the chart
helm install oodle-observability oodle/oodle-k8s-observability \
  --values my-values.yaml \
  --namespace oodle-monitoring \
  --create-namespace
```

### Install from Source

```bash
# Clone and install locally
git clone https://github.com/oodle-ai/oodle-k8s-observability-helm.git
cd oodle-k8s-observability-helm

helm install oodle-observability . \
  --values my-values.yaml \
  --namespace oodle-monitoring \
  --create-namespace
```

## Configuration

### Required Configuration

#### Step 1: Create the API Key Secret

Before installing the chart, create a Kubernetes secret containing your Oodle API key:

```bash
kubectl create secret generic oodle-api-key \
  --from-literal=apiKey=YOUR_API_KEY \
  --namespace oodle-monitoring
```

#### Step 2: Configure the Chart

Create a values file with your cluster-specific settings:

```yaml
# Centralized configuration - all components will use these values
oodleConfig:
  enabled: true
  clusterName: "your-cluster-name"
  oodleInstance: "inst-your-instance-id"
  
  # Optional: Override default endpoints
  # If not specified, they will be auto-generated from oodleInstance:
  #   oodleLogsHost: https://{oodleInstance}-logs.collector.oodle.ai
  #   oodleMetricsHost: https://{oodleInstance}.collector.oodle.ai
  # oodleLogsHost: "https://custom-logs.example.com"
  # oodleMetricsHost: "https://custom-metrics.example.com"

# Enable/disable components as needed
vmagent:
  enabled: true

auto-instrumentation:
  enabled: true

vector-agent:
  enabled: true

vector-aggregator:
  enabled: true

event-exporter:
  enabled: true
```

**That's it!** The chart automatically uses the secret you created (`oodle-api-key`) for all components.

<details>
<summary><b>Using a Custom Secret Name</b> (click to expand)</summary>

If you need to use a different secret name or key, override the secret references in the affected components:

```yaml
# Override secret references to use your custom secret
vmagent:
  env:
    - name: OODLE_API_KEY
      valueFrom:
        secretKeyRef:
          name: my-custom-secret
          key: myApiKey

vector-aggregator:
  env:
    - name: OODLE_API_KEY
      valueFrom:
        secretKeyRef:
          name: my-custom-secret
          key: myApiKey

event-exporter:
  extraEnvVars:
    - name: OODLE_API_KEY
      valueFrom:
        secretKeyRef:
          name: my-custom-secret
          key: myApiKey
```

</details>

**Note:** The chart automatically creates:
- A ConfigMap named `oodle-k8s-observability-config` containing cluster name, instance ID, and endpoint URLs
  - If `oodleLogsHost` or `oodleMetricsHost` are not specified, they will be auto-generated from `oodleInstance`
  - Pattern: `https://{oodleInstance}.collector.oodle.ai` (metrics) and `https://{oodleInstance}-logs.collector.oodle.ai` (logs)

You must create your own Secret with the Oodle API key before installing the chart. This provides better security and allows you to manage secrets separately using your preferred secrets management solution.

### Advanced: External ConfigMap Management

<details>
<summary><b>Using a Manually Created ConfigMap</b> (click to expand)</summary>

If you prefer to manage the ConfigMap externally (e.g., using GitOps tools, External Secrets Operator, or other configuration management), you can disable the chart's ConfigMap creation:

**Step 1:** Create your ConfigMap manually:

```bash
kubectl create configmap oodle-k8s-observability-config \
  --from-literal=clusterName=your-cluster-name \
  --from-literal=oodleInstance=inst-your-instance-id \
  --from-literal=oodleLogsHost=https://inst-your-instance-logs.collector.oodle.ai \
  --from-literal=oodleMetricsHost=https://inst-your-instance.collector.oodle.ai \
  --namespace oodle-monitoring
```

**Step 2:** Install the chart with ConfigMap creation disabled:

```yaml
oodleConfig:
  enabled: false  # Disable ConfigMap creation

# Components will still reference the manually created ConfigMap
vmagent:
  enabled: true

auto-instrumentation:
  enabled: true

vector-agent:
  enabled: true

vector-aggregator:
  enabled: true

event-exporter:
  enabled: true
```

**Note:** The ConfigMap must be named `oodle-k8s-observability-config` and must contain all required keys (`clusterName`, `oodleInstance`, `oodleLogsHost`, `oodleMetricsHost`).

</details>

### Component Control

Enable or disable components as needed:

```yaml
kube-state-metrics:      # Kubernetes object metrics
  enabled: true
prometheus-node-exporter: # Node-level metrics
  enabled: true
vmagent:                  # Metrics collection and forwarding
  enabled: true
auto-instrumentation:     # eBPF-based auto-instrumentation
  enabled: true
vector-agent:             # Log collection
  enabled: true
vector-aggregator:        # Log processing and forwarding
  enabled: true
event-exporter:           # Kubernetes events collection
  enabled: true
```

## Upgrading

```bash
helm upgrade oodle-observability . -f my-values.yaml
```

## Uninstalling

```bash
helm uninstall oodle-observability --namespace oodle-monitoring
```

## Troubleshooting

Check the status of all components:

```bash
# Check pods
kubectl get pods -n oodle-monitoring
```

## Support

- [Oodle Documentation](https://docs.oodle.ai)
- [GitHub Issues](https://github.com/oodle-ai/oodle-k8s-observability-helm/issues)
