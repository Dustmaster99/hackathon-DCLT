# Velero no AWS Academy — SolidaryTech

## Objetivo

Esta implementação instala o Velero no EKS e grava os backups em um bucket S3
na região `us-west-2`, separado do cluster primário em `us-east-1`.

Ela foi adaptada às limitações do AWS Academy:

- não cria IAM User;
- não cria IAM Role para o Velero;
- usa as credenciais temporárias da sessão em um Secret Kubernetes;
- pode ser habilitada ou desabilitada por flag;
- cria bucket versionado, criptografado e sem acesso público;
- agenda backup dos namespaces críticos a cada 15 minutos;
- instala o Node Agent para File System Backup.

## Limitação crítica do ambiente atual

O PostgreSQL usa um PersistentVolume do tipo `hostPath`. O File System Backup do
Velero não suporta volumes `hostPath`. Portanto:

- os manifestos Kubernetes são protegidos;
- o conteúdo atual do volume PostgreSQL não é protegido pelo Velero;
- o RPO de dados de doações ainda depende de `pg_dump` periódico ou da migração
  para um PVC EBS/CSI compatível.

Não declare o RPO de 15 minutos como comprovado até restaurar e validar os dados
do PostgreSQL.

## Ativação

No arquivo local e ignorado `terraform.tfvars`:

```hcl
enable_velero           = true
velero_backup_region    = "us-west-2"
velero_backup_schedule  = "*/15 * * * *"
velero_backup_ttl_hours = 48
```

As três credenciais temporárias do AWS Academy devem estar atualizadas:

```hcl
aws_access_key_id_secret     = "..."
aws_secret_access_key_secret = "..."
aws_session_token_secret     = "..."
```

Aplicação isolada:

```powershell
cd .\terraforming-infraestructure\enviroments\fiap-lab5

terraform init
terraform plan -target=module.velero
terraform apply -target=module.velero
```

O `-target` é adequado aqui para introduzir o módulo isoladamente no ambiente
existente. Depois, execute um `terraform plan` completo para confirmar que não
restaram alterações não planejadas.

## Validação

```powershell
kubectl get pods -n velero
kubectl get backupstoragelocations -n velero
kubectl get schedules -n velero
terraform output velero_backup_bucket
```

Resultados esperados:

- Deployment `velero` em `Running`;
- DaemonSet do Node Agent disponível no nó;
- BackupStorageLocation `default` em `Available`;
- Schedule `solidarytech-critical` habilitado.

## Backup manual

Se a CLI `velero` estiver instalada:

```powershell
$backupName = "solidarytech-manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

velero backup create $backupName `
  --include-namespaces fiap-microservices,argocd,ingress-nginx,monitoring `
  --default-volumes-to-fs-backup `
  --snapshot-volumes=false `
  --wait

velero backup describe $backupName --details
velero backup logs $backupName
```

Sem a CLI, crie o recurso pelo Kubernetes:

```powershell
$backupName = "solidarytech-manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

@"
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $backupName
  namespace: velero
spec:
  includedNamespaces:
    - fiap-microservices
    - argocd
    - ingress-nginx
    - monitoring
  storageLocation: default
  snapshotVolumes: false
  defaultVolumesToFsBackup: true
  ttl: 48h0m0s
"@ | kubectl apply -f -

kubectl get backup -n velero $backupName
kubectl describe backup -n velero $backupName
```

## Teste de restauração seguro

Para uma primeira evidência, restaure somente recursos não persistentes em um
namespace temporário. Não restaure por cima do ambiente ativo sem uma janela de
mudança.

```powershell
velero restore create solidarytech-restore-test `
  --from-backup $backupName `
  --namespace-mappings fiap-microservices:fiap-microservices-restore `
  --wait

velero restore describe solidarytech-restore-test --details
kubectl get all -n fiap-microservices-restore
```

Alguns recursos com nomes globais, dependências externas ou namespaces fixos
podem exigir exclusão ou ajuste durante um restore de teste.

## Renovação das credenciais

As credenciais do AWS Academy expiram. Depois de atualizar o `terraform.tfvars`,
execute:

```powershell
terraform apply -target=module.velero
kubectl rollout restart deployment/velero -n velero
kubectl rollout restart daemonset/velero-node-agent -n velero
kubectl rollout status deployment/velero -n velero
```

Em seguida, confirme:

```powershell
kubectl get backupstoragelocations -n velero
```

Se o local estiver `Unavailable`, verifique:

```powershell
kubectl logs deployment/velero -n velero --tail=200
```

## Evidências para a entrega

Registre:

1. bucket na região `us-west-2`, com versionamento e criptografia;
2. Pods do Velero e Node Agent em execução;
3. BackupStorageLocation em `Available`;
4. Schedule configurado a cada 15 minutos;
5. backup manual em `Completed`;
6. objetos armazenados no S3;
7. restore de teste em `Completed`;
8. recursos restaurados no namespace temporário;
9. tempo de backup e restauração;
10. ressalva de que o volume `hostPath` do PostgreSQL precisa de proteção
    complementar.

## Caminho recomendado para produção

Fora do AWS Academy, substitua as credenciais estáticas por IRSA ou EKS Pod
Identity com uma role de menor privilégio. Migre o PostgreSQL para armazenamento
gerenciado ou PVC EBS/CSI, adicione backup lógico consistente e execute testes
periódicos de restauração.

