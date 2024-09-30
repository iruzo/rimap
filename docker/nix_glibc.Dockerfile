FROM nixos/nix:latest AS builder

WORKDIR /rimap

COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY flake.nix ./flake.nix
COPY flake.lock ./flake.lock

# Build our Nix environment
RUN nix \
    --extra-experimental-features "nix-command flakes" \
    --option filter-syscalls false \
    build

RUN mkdir /tmp/nix-store-closure
RUN cp -R $(nix-store -qR result/) /tmp/nix-store-closure

# FROM scratch
FROM alpine:latest

WORKDIR /app

COPY --from=builder /tmp/nix-store-closure /nix/store
COPY --from=builder /rimap/result /app

CMD ["/app/bin/rimap", "/config", "--docker"]
