use csv::ReaderBuilder;
use imap::Session;
use native_tls::TlsConnector;
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, Write};
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug)]
struct Config {
    server: String,
    username: String,
    password: String,
    local_dir: String,
}

fn read_config(config_path: &str) -> Result<Vec<Config>, Box<dyn std::error::Error>> {
    let file = File::open(config_path)?;
    let mut reader = ReaderBuilder::new()
        .has_headers(false)
        .delimiter(b',')
        .from_reader(file);

    let mut configs = Vec::new();

    for result in reader.records() {
        let record = result?;
        let server = record.get(0).unwrap_or("").to_string();
        let username = record.get(1).unwrap_or("").to_string();
        let password = record.get(2).unwrap_or("").to_string();
        let local_dir = record.get(3).unwrap_or("").to_string();

        if server.is_empty() || username.is_empty() || password.is_empty() || local_dir.is_empty() {
            return Err("Missing configuration values".into());
        }

        configs.push(Config {
            server,
            username,
            password,
            local_dir,
        });
    }

    Ok(configs)
}

fn list_all_mailboxes(
    session: &mut Session<native_tls::TlsStream<std::net::TcpStream>>,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mailboxes = session.list(None, Some("*"))?;
    let mailbox_names: Vec<String> = mailboxes.iter().map(|mb| mb.name().to_string()).collect();
    Ok(mailbox_names)
}

fn connect_to_server(
    config: &Config,
) -> Result<Session<native_tls::TlsStream<std::net::TcpStream>>, Box<dyn std::error::Error>> {
    let tls = TlsConnector::builder().build()?;
    let client = imap::connect((config.server.as_str(), 993), &config.server, &tls)?;
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

    // Default month, day, and year if not found
    let mut month = "00";
    let day = parts.get(1).unwrap_or(&"00");
    let year = parts.get(3).unwrap_or(&"00");

    // Iterate over parts to find the month
    for part in &parts {
        if let Some(&(_, num)) = months.iter().find(|&&(m, _)| m == *part) {
            month = num;
            break;
        }
    }

    // Assuming the time part is always present in the correct format
    let time_parts: Vec<&str> = parts.get(4).unwrap_or(&"00:00:00").split(':').collect();
    let (hour, minute, second) = if time_parts.len() == 3 {
        (time_parts[0], time_parts[1], time_parts[2])
    } else {
        ("00", "00", "00")
    };

    let formatted_date = format!("{}{}{}{}{}{}", year, month, day, hour, minute, second);
    Ok(formatted_date)
}


fn download_emails(
    session: &mut Session<native_tls::TlsStream<std::net::TcpStream>>,
    local_dir: &Path,
    server: &str,
    username: &str,
    use_docker_path: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let sub_dir_path = if use_docker_path {
        let dir = Path::new("/mails").to_path_buf();
        let sub_dir_name = format!("{}_{}", server, username);
        dir.join(sub_dir_name)
    } else {
        let sub_dir_name = format!("{}_{}", server, username);
        local_dir.join(sub_dir_name)
    };

    fs::create_dir_all(&sub_dir_path)?;

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

            let timestamp = parse_date(&date)?;

            let from = extract_between_last_brackets(&sanitize_filename(&from)).to_string();

            let email_filename = format!("{}_{}.eml", timestamp, from);
            let email_path = sub_dir_path.join(&email_filename); // Save to subdirectory

            if !email_path.exists() {
                let mut file = File::create(email_path)?;
                file.write_all(body)?;
                println!("Downloaded {}|{}|{}", server, username, email_filename);
            } else {
                println!("Mail already present: {}|{}|{}", server, username, email_filename);
            }
        }
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 || args.len() > 3 {
        eprintln!("Usage: {} <config_path> [--docker]", args[0]);
        return Ok(());
    }

    let config_path = &args[1];
    let use_docker_path = args.get(2).map_or(false, |arg| arg == "--docker");
    let configs = read_config(config_path)?;

    for config in configs {
        let local_dir = Path::new(&config.local_dir);
        if !use_docker_path {
            fs::create_dir_all(local_dir)?;
        }

        let mut session = connect_to_server(&config)?;
        let mailboxes = list_all_mailboxes(&mut session)?;

        for mailbox in mailboxes {
            session.select(&mailbox)?;
            download_emails(
                &mut session,
                local_dir,
                &config.server,
                &config.username,
                use_docker_path,
            )?;
        }

        session.logout()?;
    }

    Ok(())
}
