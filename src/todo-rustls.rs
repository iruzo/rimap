use rustls_connector::RustlsConnector;
use std::env;
use std::fs::{self, File};
use std::io::{self, BufRead, Write};
use std::net::TcpStream;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use log::info;

struct Config {
    server: String,
    username: String,
    password: String,
    local_dir: String,
}

fn read_config(config_path: &str) -> Result<Config, Box<dyn std::error::Error>> {
    let file = File::open(config_path)?;
    let reader = io::BufReader::new(file);

    let mut server = String::new();
    let mut username = String::new();
    let mut password = String::new();
    let mut local_dir = String::new();

    for line in reader.lines() {
        let line = line?;
        if line.starts_with('#') || line.trim().is_empty() {
            continue;
        }
        let mut parts = line.splitn(2, '=');
        let key = parts.next().unwrap().trim();
        let value = parts.next().unwrap().trim().to_string();

        match key {
            "server" => server = value,
            "username" => username = value,
            "password" => password = value,
            "local_dir" => local_dir = value,
            _ => (),
        }
    }

    if server.is_empty() || username.is_empty() || password.is_empty() || local_dir.is_empty() {
        return Err("Missing configuration values".into());
    }

    Ok(Config {
        server,
        username,
        password,
        local_dir,
    })
}

fn list_all_mailboxes(
    session: &mut imap::Session<rustls_connector::rustls::StreamOwned<rustls_connector::rustls::ClientConnection, rustls_connector::rustls::StreamOwned<rustls_connector::rustls::ClientConnection, std::net::TcpStream>>>,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mailboxes = session.list(None, Some("*"))?;
    let mailbox_names: Vec<String> = mailboxes.iter().map(|mb| mb.name().to_string()).collect();
    Ok(mailbox_names)
}

fn connect_to_server(
    config: &Config,
) -> std::result::Result<imap::Session<rustls_connector::rustls::StreamOwned<rustls_connector::rustls::ClientConnection, rustls_connector::rustls::StreamOwned<rustls_connector::rustls::ClientConnection, std::net::TcpStream>>>, std::boxed::Box<(dyn std::error::Error + 'static)>> {

    // let mut connector = RustlsConnector::new_with_native_certs();
    // if connector.is_err() {
    //     connector = Ok(RustlsConnector::new_with_webpki_roots_certs());
    // }

    let connector = RustlsConnector::new_with_webpki_roots_certs();

    let stream = TcpStream::connect((config.server.as_str(), 993))?;
    let stream = connector.connect(config.server.as_str(), stream).unwrap();

    let tls = RustlsConnector::default();
    let tlsstream = tls.connect(&config.server, stream)?;
    let client = imap::Client::new(tlsstream);
    let session = client
        .login(&config.username, &config.password)
        .map_err(|e| e.0)?;

    Ok(session)
}

fn sanitize_filename(s: &str) -> String {
    s.replace(' ', "_").to_lowercase()
}

fn extract_between_last_brackets(s: &str) -> &str {
    if let (Some(start), Some(end)) = (s.rfind('<'), s.rfind('>')) {
        if start < end {
            return &s[start + 1..end];
        }
    }
    s
}

fn parse_date(date: &str) -> Result<String, &'static str> {
    let months = [
        ("Jan", "01"),
        ("Feb", "02"),
        ("Mar", "03"),
        ("Apr", "04"),
        ("May", "05"),
        ("Jun", "06"),
        ("Jul", "07"),
        ("Aug", "08"),
        ("Sep", "09"),
        ("Oct", "10"),
        ("Nov", "11"),
        ("Dec", "12"),
    ];

    let parts: Vec<&str> = date.split_whitespace().collect();
    if parts.len() < 6 {
        return Err("Invalid date format");
    }

    let day = parts[1];
    let month = months
        .iter()
        .find(|&&(m, _)| m == parts[2])
        .map(|&(_, num)| num)
        .ok_or("Invalid month")?;
    let year = parts[3];
    let time_parts: Vec<&str> = parts[4].split(':').collect();
    if time_parts.len() != 3 {
        return Err("Invalid time format");
    }

    let hour = time_parts[0];
    let minute = time_parts[1];
    let second = time_parts[2];

    let formatted_date = format!("{}{}{}{}{}{}", year, month, day, hour, minute, second);
    Ok(formatted_date)
}

fn download_emails(
    session: &mut imap::Session<rustls_connector::rustls::StreamOwned<rustls_connector::rustls::ClientConnection, rustls_connector::rustls::StreamOwned<rustls_connector::rustls::ClientConnection, std::net::TcpStream>>>,
    local_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    let messages = session.search("ALL")?;
    for message_id in messages.iter() {
        let messages = session.fetch(message_id.to_string(), "RFC822")?;
        let message = messages.iter().next().unwrap();

        if let Some(body) = message.body() {
            let from = body
                .lines()
                .find(|line| line.as_ref().unwrap().to_lowercase().starts_with("from:"))
                .map(|line| line.unwrap()[5..].trim().to_string())
                .unwrap_or_else(|| "unknown_sender".to_string());

            let date = body
                .lines()
                .find(|line| line.as_ref().unwrap().to_lowercase().starts_with("date:"))
                .map(|line| line.unwrap()[5..].trim().to_string())
                .unwrap_or_else(|| {
                    SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .expect("Time went backwards")
                        .as_secs()
                        .to_string()
                });

            let timestamp = parse_date(&date);

            let from = extract_between_last_brackets(&sanitize_filename(&from)).to_string();

            let email_filename = format!("{}_{}.eml", timestamp.unwrap(), from);
            let email_path = local_dir.join(&email_filename);

            if !email_path.exists() {
                if let Some(body) = message.body() {
                    let mut file = File::create(email_path)?;
                    file.write_all(body)?;
                    info!("Downloaded {}", email_filename);
                }
            }
        }
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <config_path>", args[0]);
        return Ok(());
    }

    let config_path = &args[1];
    let config = read_config(config_path)?;

    let local_dir = Path::new(&config.local_dir);
    fs::create_dir_all(local_dir)?;

    let mut session = connect_to_server(&config)?;
    let mailboxes = list_all_mailboxes(&mut session)?;

    for mailbox in mailboxes {
        session.select(&mailbox)?;
        download_emails(&mut session, local_dir)?;
    }

    session.logout()?;
    Ok(())
}

