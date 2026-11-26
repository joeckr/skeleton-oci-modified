{{- define "oci-modified.secretName" -}}
{{- if .Values.secret.existingSecret -}}
{{- .Values.secret.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" .Values.app.name -}}
{{- end -}}
{{- end -}}
