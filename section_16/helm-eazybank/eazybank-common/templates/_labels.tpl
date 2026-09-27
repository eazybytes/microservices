{{/*
Labels shared by every eazybank resource. Pass the root context (.).
Never use these in a selector - selectors are immutable and helm.sh/chart
changes on every chart version bump.
*/}}
{{- define "eazybank.commonLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.global.partOf | default "eazybank" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Labels for a component's Deployment/Service metadata.
Usage: {{ include "eazybank.labels" (dict "ctx" $ "name" "redis") }}
*/}}
{{- define "eazybank.labels" -}}
app: {{ .name }}
app.kubernetes.io/name: {{ .name }}
{{ include "eazybank.commonLabels" .ctx }}
{{- end -}}

{{/*
Labels for a component's pod template. Leaves out helm.sh/chart and
managed-by so a chart version bump alone doesn't roll every pod.
Usage: {{ include "eazybank.podLabels" (dict "ctx" $ "name" "redis") }}
*/}}
{{- define "eazybank.podLabels" -}}
app: {{ .name }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/part-of: {{ .ctx.Values.global.partOf | default "eazybank" }}
{{- end -}}
