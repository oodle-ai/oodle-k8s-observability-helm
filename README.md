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

This chart uses ConfigMap and Secret for centralized configuration management. Create a values file with your cluster-specific settings:

```yaml
# Centralized configuration - all components will use these values
oodleConfig:
  enabled: true
  clusterName: "your-cluster-name"
  oodleInstance: "inst-your-instance-id"
  oodleApiKey: "your-api-key"
  # oodleLogsHost and oodleMetricsHost are optional
  # If not specified, they will be auto-generated from oodleInstance:
  #   oodleLogsHost: https://{oodleInstance}-logs.collector.oodle.ai
  #   oodleMetricsHost: https://{oodleInstance}.collector.oodle.ai
  # Uncomment and specify custom values if needed:
  # oodleLogsHost: "https://custom-logs.example.com"
  # oodleMetricsHost: "https://custom-metrics.example.com"

# Metrics collection configuration
vmagent:
  enabled: true

# Auto-instrumentation configuration
auto-instrumentation:
  enabled: true

# Log collection configuration
vector-agent:
  enabled: true

vector-aggregator:
  enabled: true

# Kubernetes events configuration
event-exporter:
  enabled: true
```

**Note:** The chart automatically creates:
- A ConfigMap named `oodle-k8s-observability-config` containing cluster name, instance ID, and endpoint URLs
  - If `oodleLogsHost` or `oodleMetricsHost` are not specified, they will be auto-generated from `oodleInstance`
  - Pattern: `https://{oodleInstance}.collector.oodle.ai` (metrics) and `https://{oodleInstance}-logs.collector.oodle.ai` (logs)
- A Secret named `oodle-k8s-observability-secrets` containing the API key

All sub-charts automatically reference these resources for their environment variables.

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
