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

### Scrape Job Configuration (Opt-in Feature)

> **⚠️ Note:** This is an opt-in feature disabled by default for backwards compatibility.
> Existing users can continue using `vmagent.config.scrape_configs` as before.

When enabled, you can individually enable/disable scrape jobs and add metric drop rules without modifying the entire scrape configuration.

#### Enabling Managed Scrape Config

To use the managed scrape configuration feature, add **both** settings to your values file:

```yaml
vmagent:
  managedScrapeConfig:
    enabled: true
  configMap: "vmagent-scrape-config"  # Required when managedScrapeConfig is enabled
```

> ⚠️ **Important:** When `managedScrapeConfig.enabled` is `true`, you **must** set `configMap: "vmagent-scrape-config"`. The chart will not work correctly without this setting.

#### Scrape Interval and Timeout

Configure global scrape interval and timeout for all jobs:

```yaml
vmagent:
  managedScrapeConfig:
    enabled: true
    scrape_interval: 60s   # How often to scrape targets (default: 60s)
    scrape_timeout: 1m     # Timeout for each scrape request (default: 1m)
  configMap: "vmagent-scrape-config"
```

You can also override these settings per-job for fine-grained control:

```yaml
vmagent:
  managedScrapeConfig:
    enabled: true
    scrape_interval: 60s   # Global default
    scrape_timeout: 1m     # Global default
  configMap: "vmagent-scrape-config"
  
  scrapeJobs:
    # API server metrics - scrape less frequently (reduce load)
    KubernetesApiServers:
      enabled: true
      scrape_interval: 120s
      scrape_timeout: 90s
    
    # cAdvisor - scrape more frequently for container metrics
    kubernetesNodesCadvisor:
      enabled: true
      scrape_interval: 30s
      scrape_timeout: 25s
    
    # Other jobs use global defaults (60s interval, 1m timeout)
    kubernetesNodes:
      enabled: true
    kubeStateMetrics:
      enabled: true
```

> **Note:** `scrape_timeout` should always be less than or equal to `scrape_interval`.

#### Available Scrape Jobs

| Job Name | Values Key | Description |
|----------|------------|-------------|
| `kubernetes-apiservers` | `scrapeJobs.KubernetesApiServers` | Kubernetes API server metrics |
| `kubernetes-nodes` | `scrapeJobs.kubernetesNodes` | Kubelet metrics from each node |
| `kubernetes-nodes-cadvisor` | `scrapeJobs.kubernetesNodesCadvisor` | cAdvisor container metrics |
| `kube-state-metrics` | `scrapeJobs.kubeStateMetrics` | Kubernetes object state metrics |
| `node-exporter` | `scrapeJobs.nodeExporter` | Node-level hardware/OS metrics |
| `kubernetes-pods` | `scrapeJobs.kubernetesPods` | Pods with `prometheus.io/scrape: true` annotation |
| `oodle-beyla` | `scrapeJobs.oodleBeyla` | Beyla eBPF auto-instrumentation metrics |

#### Disabling Scrape Jobs

To disable specific scrape jobs, enable managed config and set their `enabled` field to `false`:

```yaml
vmagent:
  # Enable managed scrape config
  managedScrapeConfig:
    enabled: true
  configMap: "vmagent-scrape-config"
  
  scrapeJobs:
    # Disable API server metrics collection
    KubernetesApiServers:
      enabled: false
    
    # Disable cAdvisor metrics (container metrics)
    kubernetesNodesCadvisor:
      enabled: false
    
    # Keep other jobs enabled (default)
    kubernetesNodes:
      enabled: true
    kubeStateMetrics:
      enabled: true
    nodeExporter:
      enabled: true
    kubernetesPods:
      enabled: true
    oodleBeyla:
      enabled: true
```

### Metric Drop Rules

You can drop or filter metrics using `metric_relabel_configs`. There are two approaches depending on your setup:

#### Option 1: Using Managed Scrape Config (Recommended for new deployments)

When `managedScrapeConfig.enabled: true`, you can add drop rules per-job:

```yaml
vmagent:
  managedScrapeConfig:
    enabled: true
  configMap: "vmagent-scrape-config"
  
  scrapeJobs:
    # Drop specific metrics from API server
    KubernetesApiServers:
      enabled: true
      metric_relabel_configs:
        # Drop histogram bucket metrics (high cardinality)
        - source_labels: [__name__]
          regex: "apiserver_request_duration_seconds_bucket"
          action: drop
        # Drop metrics with specific labels
        - source_labels: [verb]
          regex: "WATCH"
          action: drop
    
    # Drop Go runtime metrics from node-exporter
    nodeExporter:
      enabled: true
      metric_relabel_configs:
        - source_labels: [__name__]
          regex: "go_.*"
          action: drop
    
    # Filter cAdvisor metrics - keep only essential container metrics
    kubernetesNodesCadvisor:
      enabled: true
      metric_relabel_configs:
        - source_labels: [__name__]
          regex: "(container_cpu_usage_seconds_total|container_memory_working_set_bytes|container_network_.*)"
          action: keep
```

#### Option 2: Using Default Config (For existing deployments)

If you're not using managed scrape config, add `metric_relabel_configs` directly to `vmagent.config.scrape_configs`:

```yaml
vmagent:
  config:
    scrape_configs:
      - job_name: kubernetes-apiservers
        # ... existing config ...
        metric_relabel_configs:
          - source_labels: [__name__]
            regex: "apiserver_request_duration_seconds_bucket"
            action: drop
```

#### Common Metric Relabel Patterns

<details>
<summary><b>Drop by Metric Name Prefix</b></summary>

```yaml
metric_relabel_configs:
  # Drop all metrics starting with 'go_'
  - source_labels: [__name__]
    regex: "go_.*"
    action: drop
  
  # Drop multiple prefixes
  - source_labels: [__name__]
    regex: "(go_|process_|promhttp_).*"
    action: drop
```

</details>

<details>
<summary><b>Drop by Label Value</b></summary>

```yaml
metric_relabel_configs:
  # Drop metrics from specific namespace
  - source_labels: [namespace]
    regex: "kube-system"
    action: drop
  
  # Drop metrics with specific job label
  - source_labels: [job]
    regex: "some-noisy-job"
    action: drop
  
  # Drop based on multiple labels
  - source_labels: [namespace, pod]
    separator: ";"
    regex: "default;my-noisy-pod.*"
    action: drop
```

</details>

<details>
<summary><b>Keep Only Specific Metrics</b></summary>

```yaml
metric_relabel_configs:
  # Keep only essential metrics (drop everything else)
  - source_labels: [__name__]
    regex: "(up|container_cpu_usage_seconds_total|container_memory_working_set_bytes|kube_pod_status_phase)"
    action: keep
```

</details>

<details>
<summary><b>Drop High-Cardinality Histogram Buckets</b></summary>

```yaml
metric_relabel_configs:
  # Drop histogram bucket metrics (keep sum and count)
  - source_labels: [__name__]
    regex: ".*_bucket"
    action: drop
  
  # Or drop specific histogram buckets
  - source_labels: [__name__]
    regex: "(apiserver_request_duration_seconds_bucket|etcd_request_duration_seconds_bucket)"
    action: drop
```

</details>

<details>
<summary><b>Remove High-Cardinality Labels</b></summary>

```yaml
metric_relabel_configs:
  # Remove 'le' label (histogram bucket boundaries) - use with caution
  - regex: "le"
    action: labeldrop
  
  # Remove labels matching a pattern
  - regex: "kubernetes_io_.*"
    action: labeldrop
```

</details>

#### Adding Custom Scrape Jobs

Use `extraScrapeConfigs` to add additional scrape jobs:

```yaml
vmagent:
  extraScrapeConfigs:
    - job_name: my-custom-app
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        - source_labels: [__meta_kubernetes_pod_label_app]
          action: keep
          regex: "my-app"
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: (.+)
          target_label: __address__
          replacement: $1
      metric_relabel_configs:
        - source_labels: [__name__]
          regex: "my_app_important_.*"
          action: keep
```

For more information on metric relabeling, see:
- [VictoriaMetrics vmagent documentation](https://docs.victoriametrics.com/victoriametrics/relabeling/)
- [Prometheus relabel_config documentation](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config)

### Migration Guide: Adopting Managed Scrape Config

If you're upgrading from a previous version and want to use the new managed scrape config feature:

<details>
<summary><b>Step-by-step migration</b></summary>

**Step 1:** Review your current customizations

Check if you have any customizations in `vmagent.config.scrape_configs`:
- Custom scrape jobs
- Custom `metric_relabel_configs`
- Modified relabel configs

**Step 2:** Enable managed scrape config

Add these settings to your values file:

```yaml
vmagent:
  managedScrapeConfig:
    enabled: true
  configMap: "vmagent-scrape-config"
```

**Step 3:** Migrate your customizations

- **Disabled jobs:** Set `scrapeJobs.<jobName>.enabled: false`
- **Custom metric_relabel_configs:** Add to `scrapeJobs.<jobName>.metric_relabel_configs`
- **Custom scrape jobs:** Add to `extraScrapeConfigs`

**Step 4:** Test before deploying

```bash
# Render templates locally to verify
helm template my-release ./charts/oodle-k8s-observability \
  -f my-values.yaml \
  --set oodleConfig.clusterName=test \
  --set oodleConfig.oodleInstance=inst-test \
  | grep -A 100 "name: vmagent-scrape-config"
```

**Step 5:** Deploy the upgrade

```bash
helm upgrade my-release ./charts/oodle-k8s-observability -f my-values.yaml
```

</details>

<details>
<summary><b>Staying with default config (no migration needed)</b></summary>

If you prefer to continue using `vmagent.config.scrape_configs` directly:

- **No changes required** - the default behavior is preserved
- Continue customizing `vmagent.config.scrape_configs` as before
- The `managedScrapeConfig` feature remains disabled by default

</details>

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
