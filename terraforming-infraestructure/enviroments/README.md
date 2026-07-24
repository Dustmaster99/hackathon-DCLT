# Infraestrutura Terraform — SolidaryTech

Este diretório contém os ambientes Terraform da infraestrutura do projeto. O ambiente atual está localizado em `fiap-lab5`.

## Pré-requisitos

- Terraform `>= 1.6.0`.
- AWS CLI configurada.
- Credenciais válidas para a conta AWS do laboratório.
- ARNs atualizados das roles IAM do cluster e dos nodes do EKS.

As credenciais AWS devem ser fornecidas pela cadeia padrão da AWS, por exemplo, por um perfil da AWS CLI ou pelas variáveis de ambiente:

```powershell
$env:AWS_ACCESS_KEY_ID = "..."
$env:AWS_SECRET_ACCESS_KEY = "..."
$env:AWS_SESSION_TOKEN = "..."
```

Não salve credenciais diretamente nos arquivos Terraform ou no repositório.

## Configuração do ambiente

Antes de executar o Terraform, revise o arquivo `fiap-lab5/terraform.tfvars`, especialmente:

```hcl
eks_cluster_version  = "1.35"
eks_cluster_role_arn = "arn:aws:iam::<account-id>:role/<cluster-role>"
eks_node_role_arn    = "arn:aws:iam::<account-id>:role/<node-role>"
```

Os ARNs atualmente preenchidos são antigos e precisam ser substituídos antes da criação do EKS.

## Inicialização e validação

Execute os comandos a partir da pasta do ambiente:

```powershell
cd terraforming-infraestructure\enviroments\fiap-lab5
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Para criar toda a infraestrutura de acordo com o plano:

```powershell
terraform apply
```

## Implantação seletiva

O uso de `-target` é útil para testes ou recuperação pontual. Para o fluxo normal, prefira `terraform plan` e `terraform apply` sem targets, permitindo que o Terraform respeite todo o grafo de dependências.

### VPC — infraestrutura de rede

A VPC deve existir antes do cluster EKS:

```powershell
terraform plan -target="module.vpc"
terraform apply -target="module.vpc"
```

### ECR — repositórios de imagens

```powershell
terraform plan -target="module.ecr"
terraform apply -target="module.ecr"
```

São criados repositórios para `ngo-service`, `donation-service`, `volunteer-service` e `postgres`.

### DynamoDB — voluntários

```powershell
terraform plan -target="module.volunteers_dynamodb"
terraform apply -target="module.volunteers_dynamodb"
```

A tabela criada é `SolidaryTechVolunteers`, utilizada pelo `volunteer-service`.

### SQS — eventos de doações

```powershell
terraform plan -target="module.donation_events_sqs"
terraform apply -target="module.donation_events_sqs"
```

A fila principal é `solidary-donations`, utilizada pelo `donation-service`, e o módulo também cria uma dead-letter queue.

### EKS — cluster Kubernetes

Antes de criar o cluster, confirme que as roles IAM são válidas e que a VPC possui subnets privadas em pelo menos duas zonas de disponibilidade distintas.

```powershell
terraform plan -target="module.eks"
terraform apply -target="module.eks"
```

## Ordem sugerida

1. VPC.
2. ECR, DynamoDB e SQS.
3. EKS.
4. Implantação das aplicações no Kubernetes.

## Outputs

Após a implantação, consulte os valores exportados pelos módulos com:

```powershell
terraform output
```

