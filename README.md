Rimap is a simple rust program to download your emails using IMAP.

## Usage

<details>
  <summary>Cargo</summary>

```sh
# Clone repository
cargo run -- config_file_path
```
> You need openssl
</details>


<details>
  <summary>Docker/Podman</summary>

```sh
sh <(curl -L https://raw.githubusercontent.com/iruzo/rimap/main/scripts/oneline.sh) <config_file_path> <mails_dir_path>
```
</details>


## Config file example
```ini
imap.server1.com,username1,password1,/download/dir
imap.server2.com,username2,password2,/download/dir
imap.server3.com,username3,password3,/download/dir
imap.server4.com,username4,password4,/download/dir
imap.server5.com,username5,password5,/download/dir
```
- Do not write headers in the csv
- You can use the same directory for all emails since the program will create subdirs for every email config

> OAUTH still not implemented
