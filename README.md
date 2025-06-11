# Oodle Kubernetes Observability Helm Chart

An umbrella Helm chart that provides a complete observability stack for Kubernetes clusters, including metrics, logs, and events collection.

## Overview

This chart deploys:

- **k8s-monitoring** - Kubernetes metrics collection via Prometheus remote write
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

Create a values file with your cluster-specific settings:

```yaml
monitoring:
  cluster:
    name: "your-cluster-name"
  externalServices:
    prometheus:
      host: "https://your-oodle-endpoint.com"
      apiKey: "your-api-key"
      writeEndpoint: "/v1/prometheus/your-instance/write"

auto-instrumentation:
  beyla:
    env:
      OTEL_EXPORTER_OTLP_METRICS_ENDPOINT: "https://your-oodle-endpoint.com/v1/otlp/metrics/your-instance"
      OTEL_EXPORTER_OTLP_HEADERS: "X-API-KEY=your-api-key"
      BEYLA_KUBE_CLUSTER_NAME: "your-cluster-name"

vector-agent:
  env:
    - name: CLUSTER_NAME
      value: "your-cluster-name"

vector-aggregator:
  env:
    - name: OODLE_INSTANCE
      value: "your-instance"
    - name: OODLE_API_KEY
      value: "your-api-key"
    - name: OODLE_LOGS_HOST
      value: "https://your-logs-endpoint.com"

event-exporter:
  extraEnvVars:
    - name: CLUSTER_NAME
      value: "your-cluster-name"
    - name: OODLE_INSTANCE
      value: "your-instance"
    - name: OODLE_API_KEY
      value: "your-api-key"
    - name: OODLE_LOGS_HOST
      value: "https://your-logs-endpoint.com"
```

### Component Control

Enable or disable components as needed:

```yaml
monitoring:           # Metrics collection
  enabled: true
auto-instrumentation: # eBPF instrumentation  
  enabled: true
vector-agent:         # Log collection
  enabled: true
vector-aggregator:    # Log processing
  enabled: true
event-exporter:       # Kubernetes events
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
