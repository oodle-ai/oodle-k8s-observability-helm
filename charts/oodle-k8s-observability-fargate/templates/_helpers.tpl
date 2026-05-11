{{/*
Expand the name of the chart.
*/}}
{{- define "oodle-fargate.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "oodle-fargate.fullname" -}}
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
{{- define "oodle-fargate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "oodle-fargate.labels" -}}
helm.sh/chart: {{ include "oodle-fargate.chart" . }}
{{ include "oodle-fargate.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "oodle-fargate.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oodle-fargate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Gateway selector labels
*/}}
{{- define "oodle-fargate.gatewaySelectorLabels" -}}
app.kubernetes.io/name: {{ include "oodle-fargate.name" . }}-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: gateway
{{- end }}

{{/*
Gateway labels
*/}}
{{- define "oodle-fargate.gatewayLabels" -}}
helm.sh/chart: {{ include "oodle-fargate.chart" . }}
{{ include "oodle-fargate.gatewaySelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Resolve the OTLP host endpoint.
If oodleOtlpHost is set, use it. Otherwise derive from oodleInstance.
*/}}
{{- define "oodle-fargate.otlpHost" -}}
{{- if .Values.oodleConfig.oodleOtlpHost }}
{{- .Values.oodleConfig.oodleOtlpHost }}
{{- else }}
{{- printf "https://%s-otlp.collector.oodle.ai" .Values.oodleConfig.oodleInstance }}
{{- end }}
{{- end }}

{{/*
Gateway service name
*/}}
{{- define "oodle-fargate.gatewayServiceName" -}}
{{- printf "%s-otel-gateway" (include "oodle-fargate.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Sidecar service account name
*/}}
{{- define "oodle-fargate.sidecarServiceAccountName" -}}
{{- printf "%s-otel-sidecar" (include "oodle-fargate.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Sidecar configmap name
*/}}
{{- define "oodle-fargate.sidecarConfigMapName" -}}
{{- printf "%s-otel-sidecar-config" (include "oodle-fargate.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
List of namespaces to deploy sidecar resources into.
Returns targetNamespaces if set, otherwise the release namespace.
*/}}
{{- define "oodle-fargate.sidecarNamespaces" -}}
{{- if .Values.targetNamespaces }}
{{- .Values.targetNamespaces | toJson }}
{{- else }}
{{- list .Release.Namespace | toJson }}
{{- end }}
{{- end }}

{{/*
Resolve the Oodle logs host for ES bulk API proxy.
If oodleLogsHost is set, use it. Otherwise derive from oodleInstance.
*/}}
{{- define "oodle-fargate.logsHost" -}}
{{- if .Values.fargateLogging.oodleLogsHost }}
{{- .Values.fargateLogging.oodleLogsHost }}
{{- else }}
{{- printf "%s-logs.collector.oodle.ai" .Values.oodleConfig.oodleInstance }}
{{- end }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "oodle-fargate.validateRequired" -}}
{{- if not .Values.oodleConfig.clusterName }}
  {{- fail "oodleConfig.clusterName is required" }}
{{- end }}
{{- if not .Values.oodleConfig.oodleInstance }}
  {{- fail "oodleConfig.oodleInstance is required" }}
{{- end }}
{{- end }}
