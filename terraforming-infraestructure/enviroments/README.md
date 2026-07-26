# Infraestrutura Terraform — SolidaryTech

Este diretório contém os ambientes Terraform do projeto. O ambiente atual está
em `fiap-lab5` e provisiona:

- VPC, subnets, NAT Gateways e rotas;
- cluster EKS e add-ons;
- repositórios ECR;
- DynamoDB e SQS;
- namespaces, Secrets e ingress-nginx;
- Argo CD e suas Applications;
- Grafana, Loki, Prometheus e OpenTelemetry Collector;
- volumes persistentes EBS `gp3` para observabilidade.

## Pré-requisitos

- Terraform `>= 1.6.0`;
- AWS CLI configurada;
- Helm e kubectl;
- credenciais válidas para a conta AWS;
- ARNs válidos das roles IAM do cluster e dos nodes do EKS;
- permissões para criar recursos IAM, EKS, EC2, ECR, DynamoDB e SQS.

Configure as credenciais usadas pelo Terraform:

```powershell
$env:AWS_ACCESS_KEY_ID = "SUBSTITUA"
$env:AWS_SECRET_ACCESS_KEY = "SUBSTITUA"
$env:AWS_SESSION_TOKEN = "SUBSTITUA"
```

O arquivo `fiap-lab5/terraform.tfvars` é ignorado pelo Git. Preencha nele os
valores sensíveis usados dentro dos Pods:

```hcl
aws_access_key_id_secret     = "SUBSTITUA"
aws_secret_access_key_secret = "SUBSTITUA"
aws_session_token_secret     = "SUBSTITUA"

postgres_user_secret     = "solidarytech"
postgres_password_secret = "SUBSTITUA"

grafana_admin_user     = "admin"
grafana_admin_password = "SUBSTITUA"
```

Revise também:

```hcl
eks_cluster_version  = "1.35"
eks_cluster_role_arn = "arn:aws:iam::<account-id>:role/<cluster-role>"
eks_node_role_arn    = "arn:aws:iam::<account-id>:role/<node-role>"

# Mantenha false no AWS Academy quando não for permitido criar roles IAM.
enable_ebs_persistence = false
```

Nunca envie `terraform.tfvars`, `.env`, states ou credenciais ao Git.

## Formatação de toda a infraestrutura

Na raiz do repositório:

```powershell
terraform fmt -check -recursive terraforming-infraestructure
```

Para corrigir automaticamente a formatação:

```powershell
terraform fmt -recursive terraforming-infraestructure
```

## Validação dos módulos um a um

Cada módulo pode ser inicializado e validado isoladamente. O parâmetro
`-backend=false` impede qualquer inicialização de backend durante essa
verificação.

Na raiz do repositório:

```powershell
$modules = @(
  "vpc",
  "ecr",
  "dynamodb",
  "sqs",
  "eks",
  "microservice-secrets",
  "cluster-manifests",
  "argocd",
  "argocd-applications",
  "observability"
)

foreach ($module in $modules) {
  Write-Host "Validando modulo: $module"

  terraform "-chdir=terraforming-infraestructure/modules/$module" init -backend=false -input=false
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  terraform "-chdir=terraforming-infraestructure/modules/$module" fmt -check
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  terraform "-chdir=terraforming-infraestructure/modules/$module" validate
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Os diretórios `.terraform/` criados por essa operação são ignorados pelo Git.
Não é necessário apagar esses diretórios.

Para validar somente um módulo:

```powershell
terraform -chdir=terraforming-infraestructure/modules/observability init -backend=false
terraform -chdir=terraforming-infraestructure/modules/observability fmt -check
terraform -chdir=terraforming-infraestructure/modules/observability validate
```

## Validação do ambiente integrado

Esta validação verifica o ambiente e todas as chamadas entre os módulos:

```powershell
cd terraforming-infraestructure\enviroments\fiap-lab5

terraform init
terraform fmt -check -recursive ..\..
terraform validate
```

## Criar tudo junto

Depois que o EKS e os CRDs do Argo CD já tiverem passado pelo bootstrap, todo o
ambiente pode ser planejado e aplicado junto:

```powershell
cd terraforming-infraestructure\enviroments\fiap-lab5

terraform init
terraform validate
terraform plan -out="fiap-lab5.tfplan"
terraform apply "fiap-lab5.tfplan"
```

O arquivo `*.tfplan` é ignorado pelo Git.

Também é possível aplicar sem salvar o plano:

```powershell
terraform apply
```

Em um cluster completamente novo, prefira o procedimento em fases descrito
abaixo. O provider Kubernetes precisa do endpoint do EKS e o recurso
`argoproj.io/Application` só existe depois que o Helm instala os CRDs do Argo
CD.

## Criar separadamente — bootstrap de um ambiente novo

O uso de `-target` é indicado aqui somente para o primeiro bootstrap. Depois
das etapas, sempre finalize com um `terraform plan` e `terraform apply` sem
targets para reconciliar o grafo completo.

Execute os comandos na pasta:

```powershell
cd terraforming-infraestructure\enviroments\fiap-lab5
terraform init
```

### 1. VPC

```powershell
terraform plan -target="module.vpc"
terraform apply -target="module.vpc"
```

### 2. ECR

Cria os repositórios de `ngo-service`, `donation-service`,
`volunteer-service` e `postgres`.

```powershell
terraform plan -target="module.ecr"
terraform apply -target="module.ecr"
```

### 3. DynamoDB

```powershell
terraform plan -target="module.volunteers_dynamodb"
terraform apply -target="module.volunteers_dynamodb"
```

### 4. SQS

```powershell
terraform plan -target="module.donation_events_sqs"
terraform apply -target="module.donation_events_sqs"
```

### 5. EKS

No AWS Academy, mantenha `enable_ebs_persistence = false`. Nesse modo, esta
etapa não cria role IAM, EBS CSI Driver ou associação de Pod Identity. O
Metrics Server é instalado automaticamente como add-on comunitário do EKS,
sem precisar de role IAM adicional, e disponibiliza métricas para os HPAs.

```powershell
terraform plan -target="module.eks"
terraform apply -target="module.eks"
```

Fora do AWS Academy, definir `enable_ebs_persistence = true` também cria a
role IAM do EBS CSI Driver, anexa `AmazonEBSCSIDriverPolicy` e configura Pod
Identity.

Confirme o acesso ao cluster:

```powershell
aws eks update-kubeconfig `
  --region us-east-1 `
  --name microservices-eks-cluster

kubectl get nodes
kubectl get pods -n kube-system
```

### 6. Namespaces, Secrets e ingress-nginx

O módulo `cluster_manifests` cria:

- namespaces `fiap-microservices`, `ingress-nginx` e `argocd`;
- Secrets dos serviços;
- ingress-nginx e seu Load Balancer.

```powershell
terraform plan -target="module.cluster_manifests"
terraform apply -target="module.cluster_manifests"
```

### 7. Observabilidade

Cria Grafana, Loki, Prometheus, OTel Collector e o Load Balancer exclusivo do
Grafana. Com `enable_ebs_persistence = false`, os dados ficam efêmeros e são
perdidos quando os Pods são recriados. Com a opção habilitada, também cria a
StorageClass `gp3` e os PVCs:

```powershell
terraform plan -target="module.observability"
terraform apply -target="module.observability"
```

### 8. Argo CD

Instala os CRDs e componentes do Argo CD e cria seu Load Balancer exclusivo:

```powershell
terraform plan -target="module.argocd"
terraform apply -target="module.argocd"
```

Confirme que o CRD `Application` existe:

```powershell
kubectl get crd applications.argoproj.io
kubectl get pods -n argocd
```

### 9. Argo CD Applications

Depois da instalação do CRD:

```powershell
terraform plan -target="module.argocd_applications"
terraform apply -target="module.argocd_applications"
```

O Argo CD passa a sincronizar os Deployments, Services e HPAs presentes em
`Manifestos-kubernet-service`.

### 10. Reconciliação completa

Finalize obrigatoriamente sem `-target`:

```powershell
terraform plan -out="fiap-lab5.tfplan"
terraform apply "fiap-lab5.tfplan"
```

## Criar vários módulos em uma mesma etapa

É possível agrupar componentes que não dependem uns dos outros:

```powershell
terraform plan `
  -target="module.ecr" `
  -target="module.volunteers_dynamodb" `
  -target="module.donation_events_sqs"

terraform apply `
  -target="module.ecr" `
  -target="module.volunteers_dynamodb" `
  -target="module.donation_events_sqs"
```

Após o bootstrap do cluster, Argo CD e observabilidade também podem ser
planejados juntos:

```powershell
terraform plan `
  -target="module.observability" `
  -target="module.argocd"

terraform apply `
  -target="module.observability" `
  -target="module.argocd"
```

Crie `module.argocd_applications` somente depois que o CRD do Argo CD estiver
disponível.

## Verificações após a implantação

```powershell
terraform output

kubectl get namespaces
kubectl get pods -A
kubectl get services -A
kubectl get ingress -A
kubectl get pvc -n monitoring
kubectl get applications -n argocd
```

URLs externas:

```powershell
terraform output argocd_external_url
terraform output grafana_external_url
```

## Fluxo normal após o bootstrap

Para qualquer alteração futura, use o grafo completo:

```powershell
terraform fmt -check -recursive ..\..
terraform validate
terraform plan -out="fiap-lab5.tfplan"
terraform apply "fiap-lab5.tfplan"
```

Evite `-target` no fluxo normal. O uso contínuo de targets pode deixar recursos
ou outputs fora de sincronização.
