mod config;
mod monitor;
mod procfs;
mod telegram;

use std::process::ExitCode;
use std::time::Duration;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("");

    match cmd {
        "" => exit_with(run_monitor()),
        "--version" | "-V" => {
            println!("pingmeup {VERSION}");
            ExitCode::SUCCESS
        }
        "--help" | "-h" => {
            print_help();
            ExitCode::SUCCESS
        }
        other => {
            eprintln!("[pingmeup] unknown argument: {other}");
            print_help();
            ExitCode::FAILURE
        }
    }
}

fn print_help() {
    println!("pingmeup {VERSION}");
    println!();
    println!("USAGE:");
    println!("    pingmeup            Check CPU/RAM/disk, notify Telegram if above thresholds");
    println!("    pingmeup --version  Show version");
    println!("    pingmeup --help     Show this help");
    println!();
    println!("ENV:");
    println!("    PINGMEUP_CONFIG  Override config path (default: ./config.toml or /etc/pingmeup/config.toml)");
}

fn exit_with(r: Result<(), String>) -> ExitCode {
    match r {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("[pingmeup] {e}");
            ExitCode::FAILURE
        }
    }
}

fn run_monitor() -> Result<(), String> {
    let cfg = config::load()?;
    let report = monitor::build_report(&cfg.monitor);
    if report.message.is_empty() {
        return Ok(());
    }
    let timeout = Duration::from_secs(cfg.telegram.timeout_secs);
    telegram::send(
        &cfg.telegram.bot_token,
        &cfg.telegram.chat_id,
        &report.message,
        timeout,
    )
}
