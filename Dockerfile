FROM dhi.io/golang:1.26.4 AS builder
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN go install

FROM dhi.io/golang:1.26.4 AS admission-webhook
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
WORKDIR /usr/src/app/admission-webhook
RUN go install ./cmd

FROM dhi.io/alpine-base:3.24 AS base

FROM alpine:latest AS user
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group
RUN addgroup -g 0 -S root && adduser -u 0 -G root -S root

FROM dhi.io/alpine-base:3.24
COPY --from=user /etc/passwd /etc/passwd
COPY --from=user /etc/group /etc/group
USER root
COPY --from=builder /go/bin/secrets-store-csi-driver-provider-infisical /usr/local/bin/secrets-store-csi-driver-provider-infisical
COPY --from=admission-webhook /go/bin/cmd /usr/local/bin/admission-webhook
CMD ["secrets-store-csi-driver-provider-infisical"]
