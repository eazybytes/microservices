{{- define "eazybank.configmap" -}}
{{- if not .Values.global }}
{{- fail "eazybank-common: .Values.global is not set when rendering eazybank.configmap." }}
{{- end }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.global.configMapName }}
  namespace: {{ .Values.global.namespace }}
  labels:
    {{- include "eazybank.commonLabels" . | nindent 4 }}
data:
  SPRING_PROFILES_ACTIVE: {{ .Values.global.springProfilesActive | quote }}
  SPRING_CONFIG_IMPORT: {{ .Values.global.springConfigImport | quote }}
  SPRING_CLOUD_KUBERNETES_DISCOVERY_DISCOVERY_SERVER_URL: {{ .Values.global.discoveryServerUrl | quote }}
  SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI: {{ .Values.global.jwkSetUri | quote }}
  KAFKA_BROKER: {{ .Values.global.kafkaBroker | quote }}
  REDIS_HOST: {{ .Values.global.redisHost | quote }}
  REDIS_PORT: {{ .Values.global.redisPort | quote }}
  OTLP_TRACES_ENDPOINT: {{ .Values.global.otlpTracesEndpoint | quote }}
  OTLP_LOGS_ENDPOINT: {{ .Values.global.otlpLogsEndpoint | quote }}
  OTLP_METRICS_ENDPOINT: {{ .Values.global.otlpMetricsEndpoint | quote }}
{{- end -}}
