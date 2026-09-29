{{- define "eazybank.service" -}}
{{- if not .Values.global }}
{{- fail (printf "%s: .Values.global is not set. This chart is a dependency chart and must be installed as part of eazybank-platform, not standalone. See the README.md at the root of this chart set." .Chart.Name) }}
{{- end }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.global.namespace }}
  labels:
    {{- include "eazybank.labels" (dict "ctx" . "name" .Values.appLabel) | nindent 4 }}
spec:
  selector:
    app: {{ .Values.appLabel }}
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
    - protocol: TCP
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
{{- end -}}
