FROM rust:alpine as builder

# Dependencies
RUN apk add --no-cache musl-dev mold

RUN rustup default stable
RUN USER=root cargo new --bin rimap
WORKDIR /rimap

COPY Cargo.toml Cargo.lock ./
COPY src ./src

# Build
RUN rustup target add x86_64-unknown-linux-musl
RUN RUSTFLAGS="-Ctarget-feature=+crt-static" mold -run cargo build --release --target x86_64-unknown-linux-musl

# STAGE certs
FROM alpine:latest as ca-certificates
RUN apk add -U --no-cache ca-certificates

# STAGE binary
FROM scratch

COPY --from=builder /rimap/target/x86_64-unknown-linux-musl/release/rimap /rimap
COPY --from=ca-certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["/rimap", "/config"]
