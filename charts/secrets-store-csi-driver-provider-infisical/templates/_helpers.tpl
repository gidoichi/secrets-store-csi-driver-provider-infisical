{{/*
Expand the name of the chart.
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.fullname" -}}
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
{{- define "secrets-store-csi-driver-provider-infisical.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.labels" -}}
helm.sh/chart: {{ include "secrets-store-csi-driver-provider-infisical.chart" . }}
{{ include "secrets-store-csi-driver-provider-infisical.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.selectorLabels" -}}
app.kubernetes.io/name: {{ include "secrets-store-csi-driver-provider-infisical.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "secrets-store-csi-driver-provider-infisical.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the cluster role to use
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.clusterRoleName" -}}
{{- default (include "secrets-store-csi-driver-provider-infisical.fullname" .) .Values.clusterRole.name }}
{{- end }}

{{/*
Create the name of the cluster role binding to use
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.clusterRoleBindingName" -}}
{{- default (include "secrets-store-csi-driver-provider-infisical.fullname" .) .Values.clusterRoleBinding.name }}
{{- end }}

{{/*
Selector labels for webhooks
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "secrets-store-csi-driver-provider-infisical.webhook.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create a default fully qualified app name for webhooks
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.webhook.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 55 | trimSuffix "-" }}-webhook
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 55 | trimSuffix "-" }}-webhook
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 55 | trimSuffix "-" }}-webhook
{{- end }}
{{- end }}
{{- end }}

{{/*
Expand the name for webhooks
*/}}
{{- define "secrets-store-csi-driver-provider-infisical.webhook.issuer.name" -}}
{{- default (include "secrets-store-csi-driver-provider-infisical.webhook.fullname" .) .Values.webhook.certManager.issuer.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

