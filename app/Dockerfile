# =============================================================================
# Multi-stage build — final image is ~8MB (scratch + binary)
# =============================================================================

# Stage 1: build
FROM golang:1.23-alpine AS builder

WORKDIR /src

# Cache dependency layer separately from source
COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /app/server .

# Stage 2: minimal runtime
FROM scratch

# Non-root user (scratch doesn't have useradd, so we copy passwd)
COPY --from=builder /etc/passwd /etc/passwd
USER nobody

COPY --from=builder /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
