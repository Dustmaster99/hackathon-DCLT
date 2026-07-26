# ==========================
# Etapa de build
# ==========================
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copia os arquivos de dependências
COPY go.mod go.sum ./

# Baixa os módulos
RUN go mod download

# Copia o restante do código
COPY . .

# Compila o binário
RUN CGO_ENABLED=0 GOOS=linux go build -o donation-service .

# ==========================
# Imagem final
# ==========================
FROM alpine:latest

WORKDIR /app

# Certificados HTTPS
RUN apk --no-cache add ca-certificates

# Copia o binário
COPY --from=builder /app/donation-service .

# Porta utilizada pelo serviço
EXPOSE 8082

# Executa a aplicação
CMD ["./donation-service"]
