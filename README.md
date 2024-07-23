Rimap is a simple rust program to download your emails using IMAP.

## Usage

<details>
  <summary>Cargo</summary>

```sh
# Clone repository
cargo run -- config_file_path
```
</details>


<details>
  <summary>Docker/Podman</summary>

```sh
# Clone repository
sh scripts/create_docker_glibc_image.sh # generate image with binary inside
sh scripts/run_docker_glibc_container.sh <config_file> # run docker container
```
</details>


## Config file example
```ini
server=imap.server.com
username=username
password=password
local_dir=/download/dir/path
```

> The musl version with rustls is still under development

> OAUTH still not implemented
