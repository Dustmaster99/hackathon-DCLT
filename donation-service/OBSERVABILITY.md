# Métricas do donation-service

O serviço envia métricas a cada 15 segundos por OTLP/HTTP para o endpoint
definido em `OTEL_EXPORTER_OTLP_ENDPOINT`. No Kubernetes, o destino configurado
é o OpenTelemetry Collector, que expõe as séries para coleta pelo Prometheus.

## Métricas HTTP

| Métrica OpenTelemetry | Série esperada no Prometheus | Uso |
|---|---|---|
| `donation.http.server.requests` | `donation_http_server_requests_total` | Tráfego e taxa de erros |
| `donation.http.server.request.duration` | `donation_http_server_request_duration_seconds_bucket` | Latência |

As métricas possuem os atributos:

- `http.request.method`
- `http.route`
- `http.response.status_code`

O Collector converte esses atributos para os labels Prometheus
`http_request_method`, `http_route` e `http_response_status_code`. Os recursos
OpenTelemetry também são convertidos em labels, incluindo `service_name`,
`service_version` e `deployment_environment_name`.

## Consultas PromQL

### SLI de latência

Percentual de respostas `201` do `POST /donations` concluídas em até 500 ms:

```promql
sum(rate(donation_http_server_request_duration_seconds_bucket{
  service_name="donation-service",
  http_request_method="POST",
  http_route="/donations",
  http_response_status_code="201",
  le="0.5"
}[5m]))
/
sum(rate(donation_http_server_request_duration_seconds_count{
  service_name="donation-service",
  http_request_method="POST",
  http_route="/donations",
  http_response_status_code="201"
}[5m]))
```

### SLI de taxa de erros

Percentual de respostas `5xx` entre as respostas `201` e `5xx`:

```promql
sum(rate(donation_http_server_requests_total{
  service_name="donation-service",
  http_request_method="POST",
  http_route="/donations",
  http_response_status_code=~"5.."
}[5m]))
/
sum(rate(donation_http_server_requests_total{
  service_name="donation-service",
  http_request_method="POST",
  http_route="/donations",
  http_response_status_code=~"201|5.."
}[5m]))
```

Erros do Ingress e timeouts sem resposta precisam ser combinados com métricas
do ponto de entrada da plataforma, pois não chegam ao middleware da aplicação.

### Tráfego

Requisições por segundo do `POST /donations`:

```promql
sum(rate(donation_http_server_requests_total{
  service_name="donation-service",
  http_request_method="POST",
  http_route="/donations"
}[5m]))
```

### Saturação de CPU

A CPU do pod não é medida pela aplicação. O `kube-prometheus-stack` coleta essa
informação do kubelet/cAdvisor. A utilização em relação ao CPU solicitado é:

```promql
100 *
sum(rate(container_cpu_usage_seconds_total{
  namespace="fiap-microservices",
  pod=~"donation-service-.*",
  container="donation-service"
}[5m]))
/
sum(kube_pod_container_resource_requests{
  namespace="fiap-microservices",
  pod=~"donation-service-.*",
  container="donation-service",
  resource="cpu",
  unit="core"
})
```

## Execução local

Para desabilitar a exportação quando o Collector não estiver disponível:

```text
OTEL_METRICS_EXPORTER=none
```
