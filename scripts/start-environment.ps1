[CmdletBinding()]
param(
    [string]$RegistryPrefix = "solidarytech",
    [string]$ImageTag = "latest",
    [string]$ComposeFile = "compose.yaml",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Set-Location $PSScriptRoot\..

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "O comando '$Command $($Arguments -join ' ')' falhou com o código $LASTEXITCODE."
    }
}

function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Arquivo de variáveis não encontrado: $Path"
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmedLine = $line.Trim()

        if (-not $trimmedLine -or $trimmedLine.StartsWith("#")) {
            continue
        }

        $separatorIndex = $trimmedLine.IndexOf("=")
        if ($separatorIndex -lt 1) {
            throw "Linha inválida em ${Path}: $line"
        }

        $name = $trimmedLine.Substring(0, $separatorIndex).Trim()
        $value = $trimmedLine.Substring($separatorIndex + 1).Trim()

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        Set-Item -Path "Env:$name" -Value $value
    }
}

function Assert-EnvironmentVariables {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith("replace-with-")) {
            throw "A variável '$name' não foi configurada com um valor válido em $EnvFile."
        }
    }
}

function Get-ComposeImageReference {
    param([string]$Service)

    $configJson = & docker compose --env-file $EnvFile --file $ComposeFile config --format json
    if ($LASTEXITCODE -ne 0) {
        throw "Não foi possível obter a configuração do Compose."
    }

    $projectName = ($configJson | ConvertFrom-Json).name
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        throw "O nome do projeto não foi encontrado na configuração do Compose."
    }

    $imageReference = "${projectName}-${Service}:latest"
    & docker image inspect $imageReference --format "{{.Id}}" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "A imagem '$imageReference' não foi encontrada após o build."
    }

    return $imageReference
}

try {
    Write-Step "Carregando variáveis de ambiente"
    Import-DotEnv -Path $EnvFile
    Assert-EnvironmentVariables -Names @(
        "AWS_REGION",
        "AWS_SQS_URL",
        "AWS_DYNAMODB_TABLE",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY"
    )

    if ($env:AWS_ACCESS_KEY_ID.StartsWith("ASIA")) {
        Assert-EnvironmentVariables -Names @("AWS_SESSION_TOKEN")
    }

    Write-Step "Validando AWS CLI e credenciais"
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI não encontrada no PATH."
    }

    $identityJson = & aws sts get-caller-identity --region $env:AWS_REGION --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao autenticar na AWS. Verifique as credenciais e o session token."
    }
    $identity = $identityJson | ConvertFrom-Json
    Write-Host "AWS autenticada: conta $($identity.Account), identidade $($identity.Arn)" -ForegroundColor Green

    Write-Step "Validando acesso à fila SQS"
    Invoke-CheckedCommand -Command "aws" -Arguments @(
        "sqs", "get-queue-attributes",
        "--queue-url", $env:AWS_SQS_URL,
        "--attribute-names", "QueueArn",
        "--region", $env:AWS_REGION,
        "--output", "json"
    )

    Write-Step "Validando acesso à tabela DynamoDB"
    Invoke-CheckedCommand -Command "aws" -Arguments @(
        "dynamodb", "describe-table",
        "--table-name", $env:AWS_DYNAMODB_TABLE,
        "--region", $env:AWS_REGION,
        "--query", "Table.[TableName,TableStatus]",
        "--output", "table"
    )

    Write-Step "Validando Docker e Docker Compose"
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker CLI não encontrado no PATH."
    }
    Invoke-CheckedCommand -Command "docker" -Arguments @("info")
    Invoke-CheckedCommand -Command "docker" -Arguments @("compose", "version")
    Invoke-CheckedCommand -Command "docker" -Arguments @(
        "compose", "--env-file", $EnvFile,
        "--file", $ComposeFile,
        "config", "--quiet"
    )

    Write-Step "Construindo as imagens do Compose"
    Invoke-CheckedCommand -Command "docker" -Arguments @(
        "compose", "--env-file", $EnvFile,
        "--file", $ComposeFile,
        "build"
    )

    Write-Step "Aplicando tags às imagens"
    $normalizedPrefix = $RegistryPrefix.TrimEnd("/")
    $images = [ordered]@{
        "ngo-service"       = "ngo-service"
        "donation-service"  = "donation-service"
        "volunteer-service" = "volunteer-service"
    }

    foreach ($service in $images.Keys) {
        $sourceImage = Get-ComposeImageReference -Service $service
        $targetImage = "${normalizedPrefix}/$($images[$service]):${ImageTag}"
        Invoke-CheckedCommand -Command "docker" -Arguments @("tag", $sourceImage, $targetImage)
        Write-Host "Imagem preparada: $targetImage" -ForegroundColor Green
    }

    Write-Step "Subindo a aplicação"
    Invoke-CheckedCommand -Command "docker" -Arguments @(
        "compose", "--env-file", $EnvFile,
        "--file", $ComposeFile,
        "up", "--detach"
    )

    Write-Step "Estado dos containers"
    Invoke-CheckedCommand -Command "docker" -Arguments @(
        "compose", "--env-file", $EnvFile,
        "--file", $ComposeFile,
        "ps"
    )

    Write-Host "`nAmbiente iniciado com sucesso." -ForegroundColor Green
}
catch {
    Write-Error $_
    exit 1
}
