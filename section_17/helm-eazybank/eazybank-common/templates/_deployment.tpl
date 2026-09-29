{{/*
Renders a Deployment for a Spring Boot service.

Requires .Values.global to be set (propagated automatically by Helm from
whichever parent chart installs this service as a dependency - see
eazybank-platform). Fails loudly instead of silently rendering a broken
ConfigMap reference if this chart is ever installed standalone without a
parent supplying global values.
*/}}
{{- define "eazybank.deployment" -}}
{{- if not .Values.global }}
{{- fail (printf "%s: .Values.global is not set. This chart is a dependency chart and must be installed as part of eazybank-platform (which supplies global.namespace, global.configMapName, etc.), not standalone. See the README.md at the root of this chart set." .Chart.Name) }}
{{- end }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.deploymentName }}
  namespace: {{ .Values.global.namespace }}
  labels:
    {{- include "eazybank.labels" (dict "ctx" . "name" .Values.appLabel) | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Values.appLabel }}
  template:
    metadata:
      labels:
        {{- include "eazybank.podLabels" (dict "ctx" . "name" .Values.appLabel) | nindent 8 }}
    spec:
      {{- with .Values.serviceAccountName }}
      serviceAccountName: {{ . }}
      {{- end }}
      containers:
        - name: {{ .Values.appLabel }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          {{- if .Values.containerPort }}
          ports:
            - containerPort: {{ .Values.containerPort }}
          {{- end }}
          env:
            {{- if .Values.profileEnabled }}
            - name: SPRING_PROFILES_ACTIVE
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: SPRING_PROFILES_ACTIVE
            {{- end }}
            {{- if .Values.configImportEnabled }}
            - name: SPRING_CONFIG_IMPORT
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: SPRING_CONFIG_IMPORT
            {{- end }}
            {{- if .Values.discoveryEnabled }}
            - name: SPRING_CLOUD_KUBERNETES_DISCOVERY_DISCOVERY_SERVER_URL
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: SPRING_CLOUD_KUBERNETES_DISCOVERY_DISCOVERY_SERVER_URL
            {{- end }}
            {{- if .Values.jwkEnabled }}
            - name: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI
            {{- end }}
            {{- if .Values.redisEnabled }}
            - name: SPRING_DATA_REDIS_HOST
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: REDIS_HOST
            - name: SPRING_DATA_REDIS_PORT
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: REDIS_PORT
            {{- end }}
            {{- if .Values.kafkaEnabled }}
            - name: SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: KAFKA_BROKER
            {{- end }}
            {{- if .Values.otelEnabled }}
            - name: MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: OTLP_TRACES_ENDPOINT
            - name: MANAGEMENT_OPENTELEMETRY_LOGGING_EXPORT_OTLP_ENDPOINT
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: OTLP_LOGS_ENDPOINT
            - name: MANAGEMENT_OTLP_METRICS_EXPORT_URL
              valueFrom:
                configMapKeyRef:
                  name: {{ .Values.global.configMapName }}
                  key: OTLP_METRICS_ENDPOINT
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- if .Values.containerPort }}
          startupProbe:
            httpGet:
              path: /actuator/health/readiness
              port: {{ .Values.containerPort }}
            failureThreshold: {{ .Values.startupProbe.failureThreshold }}
            periodSeconds: {{ .Values.startupProbe.periodSeconds }}
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: {{ .Values.containerPort }}
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: {{ .Values.containerPort }}
            periodSeconds: 15
          {{- end }}
{{- end -}}
