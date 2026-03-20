FROM dhi.io/golang:1.26.1 AS builder
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN go install

FROM dhi.io/golang:1.26.1 AS admission-webhook
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
WORKDIR /usr/src/app/admission-webhook
RUN go install ./cmd

FROM dhi.io/alpine-base:3.23
USER root
COPY --from=builder /go/bin/secrets-store-csi-driver-provider-infisical /usr/local/bin/secrets-store-csi-driver-provider-infisical
COPY --from=admission-webhook /go/bin/cmd /usr/local/bin/admission-webhook
CMD ["secrets-store-csi-driver-provider-infisical"]
