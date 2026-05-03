use std::path::{Path, PathBuf};

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub telegram: Telegram,
    #[serde(default)]
    pub monitor: Monitor,
}

#[derive(Debug, Deserialize)]
pub struct Telegram {
    pub bot_token: String,
    pub chat_id: String,
    #[serde(default = "default_tg_timeout")]
    pub timeout_secs: u64,
}

fn default_tg_timeout() -> u64 {
    8
}

#[derive(Debug, Deserialize)]
pub struct Monitor {
    #[serde(default = "default_threshold")]
    pub cpu_threshold: f64,
    #[serde(default = "default_threshold")]
    pub ram_threshold: f64,
    #[serde(default = "default_threshold")]
    pub disk_threshold: f64,
    #[serde(default = "default_scan_paths")]
    pub disk_scan_paths: Vec<String>,
    #[serde(default = "default_files_limit")]
    pub largest_files_limit: usize,
    #[serde(default = "default_max_msg")]
    pub max_message_length: usize,
    #[serde(default = "default_top_n")]
    pub top_processes: usize,
}

impl Default for Monitor {
    fn default() -> Self {
        Self {
            cpu_threshold: default_threshold(),
            ram_threshold: default_threshold(),
            disk_threshold: default_threshold(),
            disk_scan_paths: default_scan_paths(),
            largest_files_limit: default_files_limit(),
            max_message_length: default_max_msg(),
            top_processes: default_top_n(),
        }
    }
}

fn default_threshold() -> f64 {
    10.0
}

fn default_scan_paths() -> Vec<String> {
    vec!["/var".into(), "/home".into(), "/opt".into()]
}

fn default_files_limit() -> usize {
    5
}

fn default_max_msg() -> usize {
    3500
}

fn default_top_n() -> usize {
    3
}

pub fn load() -> Result<Config, String> {
    let path = find_config()?;
    let content = std::fs::read_to_string(&path)
        .map_err(|e| format!("read {}: {e}", path.display()))?;
    toml::from_str(&content).map_err(|e| format!("parse {}: {e}", path.display()))
}

fn find_config() -> Result<PathBuf, String> {
    if let Ok(p) = std::env::var("PINGMEUP_CONFIG") {
        let path = PathBuf::from(p);
        if path.is_file() {
            return Ok(path);
        }
        return Err(format!("PINGMEUP_CONFIG={} not found", path.display()));
    }
    for c in ["./config.toml", "/etc/pingmeup/config.toml"] {
        let p = Path::new(c);
        if p.is_file() {
            return Ok(p.to_path_buf());
        }
    }
    Err("config not found: set PINGMEUP_CONFIG, or create ./config.toml or /etc/pingmeup/config.toml".into())
}
