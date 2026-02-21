FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /app
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o umbra-server .

FROM alpine:latest
COPY --from=builder /app/umbra-server /umbra-server
EXPOSE 52224/udp
CMD ["/umbra-server"]
