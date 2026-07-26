# FinOps — SolidaryTech

Esta seção documenta a estratégia FinOps da SolidaryTech, contemplando
alocação de custos, rightsizing dos workloads e forecast mensal da
infraestrutura. Os valores financeiros são estimativas e devem ser comparados
mensalmente com o AWS Cost Explorer.

### Estratégia de tagging

A política é definida como código no Terraform e possui quatro tags centrais:

| Tag | Valor | Finalidade |
|---|---|---|
| `Project` | `SolidaryTech` | Identificar todos os recursos do projeto |
| `Environment` | `Production` | Separar os custos do ambiente produtivo |
| `CostCenter` | `NGO-Core` | Alocar os custos ao centro responsável |
| `ManagedBy` | `Terraform` | Identificar recursos gerenciados como código |

A fonte única das tags é o mapa `local.common_tags`, definido em
`terraforming-infraestructure/enviroments/fiap-lab5/main.tf`:

```hcl
locals {
  common_tags = merge(
    var.additional_tags,
    {
      Project     = "SolidaryTech"
      Environment = "Production"
      CostCenter  = "NGO-Core"
      ManagedBy   = "Terraform"
    }
  )
}
```

As tags obrigatórias aparecem depois de `additional_tags` no `merge`, evitando
que sejam sobrescritas. O provider AWS aplica esse mapa por meio de
`default_tags`, enquanto os módulos recebem explicitamente
`tags = local.common_tags`.

A política cobre:

- VPC, subnets, route tables, Internet Gateway, NAT Gateways e EIPs;
- cluster, node group e add-ons do EKS;
- instâncias EC2, discos raiz e interfaces dos workers via Launch Template;
- ECR, DynamoDB, SQS e roles IAM gerenciadas pelo projeto;
- NLBs do Ingress, Argo CD e Grafana por annotations Kubernetes;
- volumes EBS dinâmicos por `tagSpecification_N` na StorageClass do EBS CSI.

Recursos AWS que não oferecem suporte a tags, como associações de route table e
policy attachments, ficam naturalmente fora da política.

Para que as tags sejam utilizáveis nos relatórios financeiros, as chaves
`Project`, `Environment` e `CostCenter` também devem ser ativadas como
**cost allocation tags** no console de Billing da AWS. A ativação não é
retroativa: os custos passam a ser agrupados depois que a tag é ativada e
processada pelo Billing.

### Estratégia inicial de rightsizing

Rightsizing é o ajuste de CPU, memória e réplicas para manter a confiabilidade
sem reservar recursos ociosos. Reduzir requests isoladamente não reduz a
fatura do EKS; a economia ocorre quando a mudança evita novos nós ou permite
utilizar instâncias menores.

#### Métrica inicial

A métrica principal proposta é a **eficiência do CPU request no p95**:

```text
Eficiência de CPU = consumo de CPU p95 / CPU request × 100
```

Faixa inicial desejada:

| Resultado | Interpretação | Ação |
|---:|---|---|
| Menor que 40% | Request provavelmente superdimensionado | Avaliar redução |
| Entre 50% e 70% | Faixa inicial saudável | Manter e observar |
| Entre 70% e 90% | Pouca margem para picos | Avaliar aumento ou HPA |
| Maior que 90% | Risco de escala frequente e throttling | Aumentar request |

Como o HPA usa alvo de 70% do request, o objetivo não é deixar o consumo
rotineiramente acima desse valor. O p95 representa o consumo não excedido em
95% das amostras e evita dimensionar o serviço por um pico isolado.

Consulta PromQL de referência para o `donation-service`:

```promql
100 *
quantile_over_time(
  0.95,
  (
    sum(
      rate(container_cpu_usage_seconds_total{
        namespace="fiap-microservices",
        container="donation-service"
      }[5m])
    )
  )[7d:5m]
)
/
sum(
  kube_pod_container_resource_requests{
    namespace="fiap-microservices",
    container="donation-service",
    resource="cpu",
    unit="core"
  }
)
```

Como proteção complementar, deve-se acompanhar o p95 de memória:

```promql
quantile_over_time(
  0.95,
  container_memory_working_set_bytes{
    namespace="fiap-microservices",
    container="donation-service"
  }[7d]
)
```

O request de memória pode começar próximo ao p95 observado. O limit deve
acomodar o pico máximo conhecido com margem de 20% a 30%, pois ultrapassar o
limit de memória encerra o container com `OOMKilled`.

#### Baseline observado

Uma medição pontual inicial, realizada em baixa carga, apresentou:

| Workload | CPU por pod | Memória por pod | CPU request atual | CPU limit atual |
|---|---:|---:|---:|---:|
| `donation-service` | 1m | 7 MiB | 10m | 100m |
| `ngo-service` | 1m | 42 MiB | 10m | 100m |
| `volunteer-service` | 1m | 59 MiB | 10m | 100m |
| `postgres` | 6m | 42 MiB | 10m | 100m |

Essa fotografia não é suficiente para uma decisão definitiva. Ela serve para
formular os primeiros experimentos. Os manifests atuais também não reservam
nem limitam memória.

Configuração inicial proposta para validação:

| Workload | CPU request | CPU limit | Memória request | Memória limit |
|---|---:|---:|---:|---:|
| `donation-service` | 10m | 100m | 32Mi | 64Mi |
| `ngo-service` | 15m | 100m | 64Mi | 128Mi |
| `volunteer-service` | 15m | 100m | 96Mi | 192Mi |
| `postgres` | 25m | 250m | 128Mi | 256Mi |

Esses valores são candidatos de teste, não uma recomendação para aplicação
imediata. O PostgreSQL deve ser ajustado separadamente, pois seu perfil muda
com volume de dados, conexões e cache.

#### Plano de comprovação

1. **Coletar o baseline:** manter 7 a 14 dias de CPU, memória, throttling,
   OOMKills, restarts, réplicas do HPA, latência e taxa de erros.
2. **Executar teste antes da mudança:** registrar os mesmos indicadores com os
   manifests atuais.
3. **Alterar um workload por vez:** começar pelo `donation-service` e publicar
   a mudança pelo Git/Argo CD.
4. **Repetir exatamente a mesma carga:** comparar antes e depois.
5. **Executar soak test:** manter carga estável por pelo menos 30 minutos para
   observar memória, garbage collection, banco e estabilização do HPA.
6. **Aceitar ou reverter:** manter a mudança somente se os critérios abaixo
   forem atendidos.

Teste de carga proposto para `POST /donations`:

| Etapa | Carga | Duração | Objetivo |
|---|---:|---:|---|
| Aquecimento | 2 RPS | 5 min | Aquecer conexões e caches |
| Carga normal | 5 RPS | 10 min | Medir o cenário esperado |
| Carga intermediária | 10 RPS | 10 min | Observar o HPA |
| Pico | 25 RPS | 10 min | Validar margem e escalabilidade |
| Soak | 10 RPS | 30 min | Identificar crescimento de memória |

Cada execução deve utilizar dados de teste identificáveis e uma ONG válida.
Como o endpoint persiste doações, o ambiente deve possuir estratégia de limpeza
ou banco exclusivo para testes de desempenho.

Critérios de aceitação:

| Indicador | Critério |
|---|---|
| SLI de latência | Pelo menos 99% dos `201` em até 500 ms |
| Taxa de erros | No máximo 0,1% de `5xx` e timeouts |
| OOMKill | Zero |
| Restarts não planejados | Zero |
| CPU throttling | Menor que 5% do tempo de CPU |
| Memória máxima | Menor que 80% do limit |
| Eficiência do CPU request p95 | Preferencialmente entre 50% e 70% |
| HPA | Escala no pico e retorna ao mínimo após estabilização |

Consultas complementares:

```promql
# CPU throttling
sum(rate(container_cpu_cfs_throttled_periods_total{
  namespace="fiap-microservices",
  container="donation-service"
}[5m]))
/
sum(rate(container_cpu_cfs_periods_total{
  namespace="fiap-microservices",
  container="donation-service"
}[5m]))
```

```promql
# Reinicializações
sum(increase(kube_pod_container_status_restarts_total{
  namespace="fiap-microservices",
  container="donation-service"
}[1h]))
```

```promql
# Réplicas atuais e desejadas pelo HPA
kube_horizontalpodautoscaler_status_current_replicas{
  namespace="fiap-microservices",
  horizontalpodautoscaler="donation-hpa"
}

kube_horizontalpodautoscaler_status_desired_replicas{
  namespace="fiap-microservices",
  horizontalpodautoscaler="donation-hpa"
}
```

### Escalabilidade dos nós do EKS

O HPA e o Cluster Autoscaler resolvem problemas diferentes:

```text
Aumento de tráfego
      ↓
HPA aumenta as réplicas dos pods
      ↓
Scheduler tenta posicionar os novos pods
      ↓
Falta de CPU ou memória deixa pods Pending
      ↓
Cluster Autoscaler aumenta o desired size do node group
      ↓
EKS cria novos workers EC2
      ↓
Scheduler distribui os pods pendentes
```

Sem o Cluster Autoscaler, o `max_size` do managed node group é apenas um limite
permitido pela AWS: ele não aumenta nós automaticamente. A configuração do
projeto instala o chart oficial `cluster-autoscaler`, usa autodiscovery e
concede permissões AWS por EKS Pod Identity.

#### Limites configurados

| Parâmetro | Valor | Comportamento |
|---|---:|---|
| `min_size` | 1 | Mantém capacidade para pods de sistema e para o autoscaler |
| `desired_size` inicial | 1 | Capacidade criada no primeiro provisionamento |
| `max_size` | 4 | Limite financeiro e operacional do scale-out |
| Tipo da instância | `t3.large` | 2 vCPU e 8 GiB por worker antes das reservas do sistema |
| Capacidade | Spot | Reduz custo, mas pode sofrer interrupções |
| Scale-down unneeded | 10 min | Tempo ocioso antes de considerar remoção |
| Delay após adicionar nó | 10 min | Evita remover imediatamente um nó recém-criado |
| Threshold de scale-down | 50% | Nó abaixo desse nível pode ser candidato à consolidação |

O Terraform ignora alterações do `desired_size` feitas pelo autoscaler. Assim,
um novo `terraform apply` não tenta forçar o node group de volta para uma
réplica enquanto o cluster precisa de mais capacidade.

O Cluster Autoscaler não cria mais de quatro workers. Quando o limite é
atingido, pods adicionais continuam como `Pending`; esse comportamento evita
crescimento de custo sem controle e deve gerar alerta operacional.

#### Métricas de nós

Quantidade de nós disponíveis:

```promql
count(kube_node_status_condition{
  condition="Ready",
  status="true"
})
```

CPU utilizada em relação à capacidade alocável:

```promql
100 *
sum(rate(container_cpu_usage_seconds_total{
  container!="",
  image!=""
}[5m]))
/
sum(kube_node_status_allocatable{
  resource="cpu",
  unit="core"
})
```

Memória utilizada em relação à capacidade alocável:

```promql
100 *
sum(container_memory_working_set_bytes{
  container!="",
  image!=""
})
/
sum(kube_node_status_allocatable{
  resource="memory",
  unit="byte"
})
```

Pods que não conseguiram ser agendados:

```promql
sum(kube_pod_status_unschedulable)
```

Estado do Cluster Autoscaler:

```promql
cluster_autoscaler_nodes_count
```

```promql
cluster_autoscaler_unschedulable_pods_count
```

#### Teste efetivo de scale-out

O teste deve ser executado em uma janela controlada. Ele cria pods que reservam
mais CPU do que o nó atual comporta, obrigando o scheduler a deixá-los
`Pending` e acionando o Cluster Autoscaler.

Criar um namespace isolado:

```bash
kubectl create namespace finops-node-test
```

Aplicar uma carga sintética:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: node-scaling-test
  namespace: finops-node-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: node-scaling-test
  template:
    metadata:
      labels:
        app: node-scaling-test
    spec:
      containers:
        - name: pause
          image: registry.k8s.io/pause:3.10
          resources:
            requests:
              cpu: "900m"
              memory: "512Mi"
            limits:
              cpu: "900m"
              memory: "512Mi"
```

Acompanhar o teste em terminais separados:

```bash
kubectl get pods -n finops-node-test -w
```

```bash
kubectl get nodes -w
```

```bash
kubectl logs -n kube-system deployment/cluster-autoscaler -f
```

Critérios de sucesso do scale-out:

1. Pelo menos um pod fica temporariamente `Pending` por falta de CPU.
2. O log do autoscaler registra a decisão de scale-up.
3. Um novo nó entra no cluster e chega ao estado `Ready`.
4. Os pods pendentes passam para `Running`.
5. A quantidade de nós nunca ultrapassa quatro.

#### Teste do limite máximo

Escalar a carga sintética para cinco réplicas com request de `1500m` de CPU por
pod:

```bash
kubectl scale deployment node-scaling-test \
  --namespace finops-node-test \
  --replicas 5
```

Como cada pod consome a maior parte de um `t3.large`, o teste pressiona o
cluster até o limite. O resultado esperado é:

- no máximo quatro nós;
- ao menos um pod pode permanecer `Pending`;
- o autoscaler registra que o node group atingiu o tamanho máximo;
- nenhum quinto nó é criado.

Esse resultado comprova que existe um limite financeiro efetivo, não apenas
scale-out ilimitado.

#### Teste de scale-down e limpeza

Remover a carga:

```bash
kubectl delete namespace finops-node-test
```

Após a janela de estabilização, os nós ociosos devem ser drenados e o node
group deve retornar ao mínimo de um worker. Critérios:

1. Pods da aplicação não são interrompidos indevidamente.
2. O autoscaler identifica nós desnecessários.
3. Os nós extras são removidos aproximadamente 10 a 20 minutos após ficarem
   ociosos.
4. O cluster permanece com um nó `Ready`.
5. SLIs de latência e taxa de erros não são violados durante a consolidação.

Como os workers são Spot, um teste adicional opcional pode usar AWS Fault
Injection Service para simular interrupção. Esse experimento exige uma janela
própria, PodDisruptionBudgets e ao menos dois nós ativos antes da falha.

### Forecast mensal da arquitetura

#### Premissas

| Premissa | Valor |
|---|---|
| Região | `us-east-1` |
| Horas mensais | 730 |
| Cluster EKS | 1, em suporte padrão |
| Workers | 1 × `t3.large` Spot ativo durante o mês |
| NAT Gateways | 2, um por zona |
| Network Load Balancers | 3: Ingress, Argo CD e Grafana |
| Armazenamento EBS | Aproximadamente 60 GiB gp3 |
| Tráfego | Baixo, compatível com laboratório/hackathon |
| DynamoDB | `PAY_PER_REQUEST` |
| SQS | Sob demanda |
| Moeda | USD, sem impostos |
| Data de referência | Julho de 2026 |

O preço Spot varia por zona e ao longo do tempo. Para o forecast base foi
adotada a hipótese de **US$ 0,025 por hora** para um `t3.large`. O cenário de
teto utiliza o preço On-Demand de referência de aproximadamente
**US$ 0,0832 por hora**. Antes da apresentação final, a hipótese Spot deve ser
substituída pela média observada na conta AWS.

#### Projeção

| Componente | Cálculo | Forecast mensal |
|---|---:|---:|
| EKS control plane | `US$ 0,10 × 730h` | US$ 73,00 |
| 2 NAT Gateways | `2 × US$ 0,045 × 730h` | US$ 65,70 |
| 3 NLBs — parcela fixa | `3 × US$ 0,0225 × 730h` | US$ 49,28 |
| Worker `t3.large` Spot | `US$ 0,025 × 730h` | US$ 18,25 |
| EBS gp3, 60 GiB | `60 × US$ 0,08` | US$ 4,80 |
| ECR, hipótese de 5 GB | `5 × US$ 0,10` | US$ 0,50 |
| IPv4 público, hipótese de 8 endereços | `8 × US$ 0,005 × 730h` | US$ 29,20 |
| NAT por GB, NLCU, SQS, DynamoDB e saída | Reserva inicial | US$ 5,00 |
| **Total base com Spot** |  | **US$ 245,73/mês** |

No cenário em que o worker seja cobrado integralmente como On-Demand:

```text
t3.large On-Demand: US$ 0,0832 × 730h = US$ 60,74
Diferença para a hipótese Spot:        US$ 42,49
Forecast mensal de teto:               US$ 288,22
```

O forecast base considera um worker ativo. Se o node group permanecer no
máximo de quatro workers Spot durante as 730 horas, os três workers adicionais
e seus discos raiz acrescentam aproximadamente:

```text
3 workers × US$ 0,025 × 730h = US$ 54,75
3 discos × 20 GiB × US$ 0,08 = US$  4,80
Total adicional no máximo:              US$ 59,55
Forecast Spot com 4 nós permanentes:    US$ 305,28/mês
```

Na prática, o objetivo do scale-down é fazer os nós extras existirem somente
durante os picos, mantendo o custo real entre o cenário base e o máximo.

O forecast não é uma fatura garantida. NAT processado, NLCU, transferência de
dados, preço Spot e quantidade de IPv4 podem alterar o total. O relatório deve
ser atualizado mensalmente da seguinte forma:

```text
Forecast revisado =
  custos fixos
  + média diária dos custos variáveis × dias do mês
  + margem de segurança
```

Fontes oficiais de preços:

- [Amazon EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [Amazon VPC Pricing](https://aws.amazon.com/vpc/pricing/)
- [Elastic Load Balancing Pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Amazon EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [Amazon ECR Pricing](https://aws.amazon.com/ecr/pricing/)
- [AWS Public IPv4 Address Charge](https://aws.amazon.com/vpc/pricing/#Public_IPv4_Address)

#### Recomendações de otimização

**Recomendação prioritária — consolidar os NLBs:** atualmente Ingress, Argo CD
e Grafana possuem NLBs exclusivos. Argo CD e Grafana podem ser publicados pelo
mesmo Ingress com hosts distintos ou mantidos internos e acessados por VPN ou
port-forward.

Eliminar dois NLBs reduz pelo menos:

```text
2 × US$ 0,0225 × 730h = US$ 32,85/mês
```

Também reduz NLCUs e potencialmente quatro endereços IPv4 públicos:

```text
4 × US$ 0,005 × 730h = US$ 14,60/mês
```

Economia fixa potencial:

```text
US$ 32,85 + US$ 14,60 = US$ 47,45/mês
```

Outras oportunidades:

- manter o node group em Spot e diversificar famílias compatíveis para reduzir
  interrupções e aumentar a chance de capacidade;
- avaliar Graviton após publicar imagens multi-arquitetura;
- usar VPC endpoints para serviços AWS somente após comparar o custo horário
  dos endpoints com o volume processado pelo NAT;
- para ambientes não produtivos, avaliar um único NAT Gateway, aceitando a
  redução de disponibilidade por zona;
- ajustar retenção e volumes de Prometheus/Loki com base no uso real;
- avaliar instância menor somente depois do rightsizing dos workloads e da
  comprovação de margem para rollouts.
