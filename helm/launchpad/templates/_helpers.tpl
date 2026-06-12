{{/* Chart name */}}
{{- define "launchpad.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Chart name + version, for the helm.sh/chart label */}}
{{- define "launchpad.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every LaunchPad object.
NOTE: app.kubernetes.io/part-of: launchpad is load-bearing — Prometheus'
serviceMonitorSelector and our ServiceMonitor selector both key off it.
*/}}
{{- define "launchpad.labels" -}}
app.kubernetes.io/name: {{ include "launchpad.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: launchpad
helm.sh/chart: {{ include "launchpad.chart" . }}
launchpad.io/environment: {{ .Values.global.environment }}
{{- end -}}
