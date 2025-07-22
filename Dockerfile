FROM rust:alpine as builder

# Dependencies
RUN apk add --no-cache musl-dev mold openssl-dev

RUN rustup default stable
RUN USER=root cargo new --bin rimap
WORKDIR /rimap

COPY . .

# Build
RUN RUSTFLAGS="-Ctarget-feature=-crt-static" cargo build --release

# STAGE certs
FROM alpine:latest as ca-certificates
RUN apk add -U --no-cache ca-certificates

# STAGE binary
FROM alpine:latest

RUN apk add --no-cache gcc

COPY --from=builder /rimap/target/release/rimap /rimap
COPY --from=ca-certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["/rimap", "/config"]
