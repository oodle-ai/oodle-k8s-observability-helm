{{/*
Expand the name of the chart.
*/}}
{{- define "oodle-k8s-observability.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "oodle-k8s-observability.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "oodle-k8s-observability.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "oodle-k8s-observability.labels" -}}
helm.sh/chart: {{ include "oodle-k8s-observability.chart" . }}
{{ include "oodle-k8s-observability.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "oodle-k8s-observability.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oodle-k8s-observability.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Validate vmagent configuration
Ensures that when managedScrapeConfig.enabled is true, configMap is set to "vmagent-scrape-config"
*/}}
{{- define "oodle-k8s-observability.validateVmagentConfig" -}}
{{- if .Values.vmagent.managedScrapeConfig.enabled }}
  {{- if ne (default "" .Values.vmagent.configMap) "vmagent-scrape-config" }}
    {{- fail "When vmagent.managedScrapeConfig.enabled is true, vmagent.configMap must be set to 'vmagent-scrape-config'" }}
  {{- end }}
{{- end }}
{{- end }}
