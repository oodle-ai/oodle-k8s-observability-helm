# Oodle Kubernetes Observability Helm Chart

An umbrella Helm chart that provides a complete observability stack for Kubernetes clusters, including metrics, logs, and events collection.

## Overview

This chart deploys:

- **kube-state-metrics** - Kubernetes object state metrics
- **prometheus-node-exporter** - Node-level hardware and OS metrics
- **vmagent** - Prometheus metrics collection and remote write to Oodle
- **oodle-k8s-auto-instrumentation** - eBPF-based auto-instrumentation using Beyla (opt-in, disabled by default)
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

# Opt-in: eBPF service graph. Runs a privileged DaemonSet on every node.
auto-instrumentation:
  enabled: false

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
  enabled: false  # Opt-in, see Component Control

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

Enable or disable components as needed. The values below are the defaults:

```yaml
kube-state-metrics:      # Kubernetes object metrics
  enabled: true
prometheus-node-exporter: # Node-level metrics
  enabled: true
vmagent:                  # Metrics collection and forwarding
  enabled: true
auto-instrumentation:     # eBPF-based auto-instrumentation
  enabled: false          # Opt-in, see below
vector-agent:             # Log collection
  enabled: true
vector-aggregator:        # Log processing and forwarding
  enabled: true
event-exporter:           # Kubernetes events collection
  enabled: true
vmsingle:                 # In-cluster VictoriaMetrics store
  enabled: false          # Opt-in, see below
```

#### Service graph (eBPF auto-instrumentation)

`auto-instrumentation` deploys Beyla, which uses eBPF to build the service graph
automatically, with no application code changes. It is **disabled by default**: it runs a
privileged DaemonSet on every node and is not required for the metrics, logs, and events
that make up the rest of the stack.

To enable it:

```yaml
auto-instrumentation:
  enabled: true
```

The cluster name reaches Beyla as `BEYLA_KUBE_CLUSTER_NAME`, sourced from the
`oodle-k8s-observability-config` ConfigMap. Set it via `oodleConfig.clusterName`; there is
no need to set `auto-instrumentation.beyla.env.BEYLA_KUBE_CLUSTER_NAME` yourself.

### Local VictoriaMetrics Store (Opt-in Feature)

`vmsingle` deploys an in-cluster VictoriaMetrics single-node server that vmagent
dual-writes to alongside Oodle. It is **disabled by default**.

Oodle remains the system of record. This is a short-lived local cache for in-cluster
consumers that need lower query latency than a remote backend can provide, or that must
keep working during a network partition.

**When you need it:**

- **KEDA autoscaling with a fast reaction time** — the main driver. See the latency
  budget below.
- In-cluster controllers or operators that query PromQL on a hot loop.
- Any in-cluster consumer whose query volume you would rather not send to a remote
  backend.

**When you don't:** dashboards, alerting, and anything a human looks at. Query Oodle for
those — it has the full retention and the full metric set.

#### Latency budget: why local helps for KEDA

KEDA's reaction time is the sum of three delays:

| Stage | Controlled by | Typical | Tuned |
|-------|--------------|---------|-------|
| Scrape | `scrape_interval` on the relevant job | 60s | 10s |
| Remote write flush | vmagent `remoteWrite.flushInterval` | 1s | 1s |
| KEDA poll | `pollingInterval` on the ScaledObject | 30s | 10s |
| **Total (worst case)** | | **~91s** | **~21s** |

The tuned column is what gets you the 10-20s reaction time. Note that the scrape and poll
stages dominate — the local store does not by itself make scaling faster. What it buys you
is a query endpoint that is one network hop away, so a 10s `pollingInterval` stays cheap
and predictable instead of hammering a remote backend from inside a control loop.

#### Enabling it

**Two settings are required.** Enabling `vmsingle` deploys the server but does **not**
make vmagent write to it — remote write targets come from the vmagent subchart's own
values, which a parent chart cannot conditionally extend. You must also append a
`remoteWrite` entry:

```yaml
vmsingle:
  enabled: true

vmagent:
  remoteWrite:
    # Keep the existing Oodle entry first
    - url: "%{OODLE_METRICS_HOST}/v1/prometheus/%{OODLE_INSTANCE}/write"
      headers: "X-API-KEY: %{OODLE_API_KEY}"
      forcePromProto: true
    # Local store
    - url: "http://vmsingle.<namespace>.svc:8428/api/v1/write"
```

Replace `<namespace>` with your release namespace. The Service name is pinned to
`vmsingle` by `vmsingle.server.fullnameOverride` so this address is stable across
installs.

If you enable one without the other, the chart **fails at render time** with a message
telling you what to add. That is deliberate: an unwired local store runs, passes health
checks, and stays permanently empty, with nothing in any log to explain why.

#### Selective routing

Without a filter, the local store receives **every** scraped series, which is almost never
what you want for a 2Gi ephemeral cache. Use `urlRelabelConfig` on the local entry to keep
only what in-cluster consumers actually read:

```yaml
vmagent:
  remoteWrite:
    - url: "%{OODLE_METRICS_HOST}/v1/prometheus/%{OODLE_INSTANCE}/write"
      headers: "X-API-KEY: %{OODLE_API_KEY}"
      forcePromProto: true
    - url: "http://vmsingle.<namespace>.svc:8428/api/v1/write"
      urlRelabelConfig:
        # Keep only the metrics your scalers query
        - action: keep
          source_labels: [__name__]
          regex: "http_requests_total|nginx_ingress_controller_requests"
```

`urlRelabelConfig` accepts standard Prometheus relabeling, so you can filter on any label,
not just `__name__`:

```yaml
      urlRelabelConfig:
        # Keep everything from one scrape job
        - action: keep
          source_labels: [job]
          regex: "kubernetes-pods"
        # ...then narrow to one namespace
        - action: keep
          source_labels: [namespace]
          regex: "production"
```

**Routing is per target, and the targets are independent.** Each `remoteWrite` entry has
its own queue and its own filter. The Oodle entry above has no `urlRelabelConfig`, so
**Oodle keeps receiving the full metric set** regardless of what you route locally. A slow
or unavailable local store cannot affect Oodle ingestion.

#### Tuning scrape interval for the fast path

Lowering a job's `scrape_interval` affects **both** destinations — there is one scrape
feeding all remote write targets. Dropping `kubernetesPods` to 10s therefore increases
your Oodle ingest volume 6x for that job, not just the local store's.

If you only want high resolution locally, add a dedicated fast job instead of speeding up
an existing one, then route on its `job` label:

```yaml
vmagent:
  extraScrapeConfigs:
    - job_name: keda-fast
      scrape_interval: 10s
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        # Only pods opted in via annotation
        - source_labels: [__meta_kubernetes_pod_annotation_oodle_ai_fast_scrape]
          action: keep
          regex: "true"
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod

  remoteWrite:
    - url: "%{OODLE_METRICS_HOST}/v1/prometheus/%{OODLE_INSTANCE}/write"
      headers: "X-API-KEY: %{OODLE_API_KEY}"
      forcePromProto: true
      # Optional cost control: drop the 10s series from Oodle, since the
      # normal 60s jobs already cover these targets at dashboard resolution.
      urlRelabelConfig:
        - action: drop
          source_labels: [job]
          regex: "keda-fast"
    - url: "http://vmsingle.<namespace>.svc:8428/api/v1/write"
      urlRelabelConfig:
        - action: keep
          source_labels: [job]
          regex: "keda-fast"
```

This gives 10s resolution to KEDA and leaves Oodle ingest unchanged. Drop the Oodle
`urlRelabelConfig` block if you want the high-resolution series in Oodle too.

Per-job intervals on the built-in jobs are also available when
`vmagent.managedScrapeConfig.enabled` is true — see
[Scrape Job Configuration](#scrape-job-configuration-opt-in-feature).

#### ⚠️ Disk sizing: `maxDiskUsagePerURL` is per URL

`vmagent.extraArgs."remoteWrite.maxDiskUsagePerURL"` is enforced **per remote write
target**, not in total. Adding a second target doubles the worst-case on-disk queue, which
can overrun vmagent's storage during an outage.

The chart default is `17GB` against `20Gi` of storage (85%). With two targets you must
either halve the per-URL limit or double the storage:

| vmagent storage | 1 target | 2 targets |
|----------------|----------|-----------|
| 20Gi (default) | `17GB` | `8.5GB` |
| 40Gi | `34GB` | `17GB` |
| 100Gi | `85GB` | `42GB` |

```yaml
vmagent:
  # Option A: keep 20Gi, halve the per-URL budget
  extraArgs:
    remoteWrite.maxDiskUsagePerURL: "8.5GB"

  # Option B: keep 17GB per URL, double the storage
  # persistentVolume:
  #   size: 40Gi
```

#### Storage and retention

The local store defaults to ephemeral storage with short retention, because a cache for
autoscaling only needs a recent window and losing it on restart is harmless:

```yaml
vmsingle:
  enabled: true
  server:
    retentionPeriod: 1d       # VictoriaMetrics enforces a 24h minimum
    persistentVolume:
      enabled: false          # emptyDir; no PVC or StorageClass needed
    emptyDir:
      sizeLimit: 2Gi
```

**`retentionPeriod` units:** `h`, `d`, `w`, `y`. A bare number means **months** — `1` is
one month, not one day.

Switch to a PVC if the local store must survive pod restarts:

```yaml
vmsingle:
  server:
    retentionPeriod: 7d
    persistentVolume:
      enabled: true
      size: 10Gi
      storageClassName: ""    # cluster default
```

#### Pointing KEDA at the local store

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app
spec:
  scaleTargetRef:
    name: my-app
  pollingInterval: 10         # default is 30
  cooldownPeriod: 60
  minReplicaCount: 2
  maxReplicaCount: 20
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://vmsingle.<namespace>.svc:8428
        query: sum(rate(http_requests_total{namespace="production"}[1m]))
        threshold: "100"
```

If KEDA runs in a different namespace from this chart, the address is still
`http://vmsingle.<release-namespace>.svc:8428` — cross-namespace Service DNS resolves
normally, subject to any NetworkPolicy you have in place.

#### Verifying

```bash
# The local store should be receiving samples
kubectl exec -n <namespace> statefulset/vmsingle -- \
  wget -qO- 'http://localhost:8428/api/v1/query?query=count({__name__=~".%2B"})'

# Confirm both remote write targets are healthy (neither should be erroring)
kubectl exec -n <namespace> statefulset/<release>-vmagent -- \
  wget -qO- http://localhost:8429/metrics | grep vmagent_remotewrite_

# Confirm the query KEDA will run returns data
kubectl exec -n <namespace> statefulset/vmsingle -- \
  wget -qO- --post-data='query=sum(rate(http_requests_total[1m]))' \
  http://localhost:8428/api/v1/query
```

If the local store is empty, check that your `urlRelabelConfig` keep rule actually matches
— an over-narrow `regex` silently drops everything, which looks identical to a broken
connection.

### Log Metadata Fields

`vector-agent` enriches every log line with Kubernetes metadata under `kubernetes.*`.
Some of that metadata is unbounded — pod labels and annotations carry pod-template
hashes, controller revisions, and injected sidecar config — and it is repeated on
**every** log event. This chart suppresses the noisiest fields by default:

| Field | Default in this chart | Vector's own default |
|-------|----------------------|----------------------|
| `kubernetes.pod_labels` | dropped | emitted |
| `kubernetes.pod_annotations` | dropped | emitted |
| `kubernetes.pod_ip` | dropped | emitted |
| `kubernetes.pod_ips` | dropped | emitted |
| `kubernetes.namespace_labels` | dropped | emitted |
| `kubernetes.node_labels` | dropped | emitted |

Everything else is still emitted: `pod_name`, `pod_namespace`, `pod_uid`,
`pod_node_name`, `pod_owner`, `container_name`, `container_id`, `container_image`,
`container_image_id`, plus the `cluster` label.

#### Re-enabling a dropped field

A field is suppressed by setting it to `""`; to emit it again, set it back to the
event path you want the metadata written to (Vector's default path is
`kubernetes.<field>`):

```yaml
vector-agent:
  customConfig:
    sources:
      kubernetes_logs:
        pod_annotation_fields:
          # Re-emit pod labels at kubernetes.pod_labels
          pod_labels: "kubernetes.pod_labels"
```

> **⚠️ Do not use `null` to re-enable a field.** Helm does not reliably delete a
> subchart default this many levels deep, so `pod_labels: null` can leave the key
> suppressed. Always set the explicit path string.

#### Dropping more fields

The same mechanism suppresses any other field. For example, to also drop the
container image and pod owner:

```yaml
vector-agent:
  customConfig:
    sources:
      kubernetes_logs:
        pod_annotation_fields:
          container_image: ""
          container_image_id: ""
          pod_owner: ""
```

See the [Vector `kubernetes_logs` source
reference](https://vector.dev/docs/reference/configuration/sources/kubernetes_logs/)
for the full field list.

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
    kubernetesApiServers:
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
| `kubernetes-apiservers` | `scrapeJobs.kubernetesApiServers` | Kubernetes API server metrics |
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
    kubernetesApiServers:
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
    kubernetesApiServers:
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
