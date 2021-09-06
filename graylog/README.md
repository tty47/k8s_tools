# Graylog - K8S

Este repositorio inicializa todos los servicios necesarios para poder desplegar Graylog en un cluster de K8S, teniendo una replica de cada servicio, además de fluentd para poder recoger los logs y enviarlos a Graylog.

Dicho repositorio se ha utilizado para realizar pruebas de desarrollo en un entorno local.

Se creará un namespace llamado: ***graylog*** donde se desplegarán los servicios y recursos necesarios.

## Setup

Para la puesta en marcha de los servicios, ejecutar desde la raíz del proyecto:

```kubectl
kubectl apply -f .
```

## Acceso desde local

Para acceder a graylog desde local, podemos realizar un port forward hacía el servicio ejecutando:

```kubectl
kubectl port-forward service/graylog 9000:9000 -n graylog-k8s
```

## Autenticación

La autenticación por defecto que tendremos en graylog será:
- user: admin
- password: somesaltpassword

---