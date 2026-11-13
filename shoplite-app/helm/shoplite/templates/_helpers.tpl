{{/*
Labels of every ShopLite object. Call with (dict "component" "<name>" "root" .).
The NetworkPolicies (question 5c) select pods by app.kubernetes.io/name.
*/}}
{{- define "shoplite.labels" -}}
{{ include "shoplite.selectorLabels" . }}
app.kubernetes.io/part-of: shoplite
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end }}

{{- define "shoplite.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Image of a ShopLite service: [<registry>/]shoplite/<component>:<tag>.
*/}}
{{- define "shoplite.image" -}}
{{- $image := .root.Values.image -}}
{{- if $image.registry }}{{ $image.registry }}/{{ end }}shoplite/{{ .component }}:{{ required "image.tag is required" $image.tag }}
{{- end }}

{{/*
Pod security (question 5a, no container runs as root): the image's own non-root user,
and the runtime's default seccomp profile. Call with (dict "uid" N "gid" N ["fsGroup" N]).
*/}}
{{- define "shoplite.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .gid }}
{{- with .fsGroup }}
fsGroup: {{ . }}
{{- end }}
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "shoplite.containerSecurityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end }}

{{/*
The database credentials, from the Secret created outside the chart (question 5b).
*/}}
{{- define "shoplite.databaseCredentials" -}}
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ required "database.existingSecret is required" .Values.database.existingSecret }}
      key: POSTGRES_USER
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.existingSecret }}
      key: POSTGRES_PASSWORD
{{- end }}
