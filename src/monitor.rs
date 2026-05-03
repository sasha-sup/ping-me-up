use std::fmt::Write;
use std::net::UdpSocket;
use std::path::Path;

use walkdir::WalkDir;

use crate::config::Monitor;
use crate::procfs;

pub struct Report {
    pub message: String,
}

pub fn build_report(cfg: &Monitor) -> Report {
    let public_ip = public_ipv4().unwrap_or_else(|| "unknown".into());
    let cpu = procfs::cpu_usage().unwrap_or(0.0);
    let ram = procfs::ram_usage_percent().unwrap_or(0.0);
    let disk = procfs::disk_usage_percent("/").unwrap_or(0.0);

    let mut msg = String::new();

    if cpu > cfg.cpu_threshold {
        let _ = writeln!(msg, "🚨 CPU usage above threshold");
        let _ = writeln!(msg, "🌐 IP: {public_ip}");
        let _ = writeln!(msg, "⚙️ CPU usage: {cpu:.1}%");
        if let Ok(top) = procfs::top_processes(true, cfg.top_processes) {
            for p in top {
                let _ = writeln!(msg, "  {:>6} {:<16} {:>5.1}%", p.pid, p.comm, p.cpu_pct);
            }
        }
        msg.push('\n');
    }

    if ram > cfg.ram_threshold {
        let _ = writeln!(msg, "🚨 RAM usage above threshold");
        let _ = writeln!(msg, "🌐 IP: {public_ip}");
        let _ = writeln!(msg, "⚙️ RAM usage: {ram:.1}%");
        if let Ok(top) = procfs::top_processes(false, cfg.top_processes) {
            for p in top {
                let _ = writeln!(msg, "  {:>6} {:<16} {:>5.1}%", p.pid, p.comm, p.mem_pct);
            }
        }
        msg.push('\n');
    }

    if disk > cfg.disk_threshold {
        let _ = writeln!(msg, "🚨 Disk usage above threshold");
        let _ = writeln!(msg, "🌐 IP: {public_ip}");
        let _ = writeln!(msg, "💾 Disk usage: {disk:.0}%");
        msg.push_str("📂 Largest files:\n");
        let largest = collect_largest_files(&cfg.disk_scan_paths, cfg.largest_files_limit);
        if largest.is_empty() {
            msg.push_str("n/a\n");
        } else {
            for (size, path) in largest {
                let _ = writeln!(msg, "  {} {}", human_bytes(size), path);
            }
        }
        msg.push('\n');
    }

    if msg.len() > cfg.max_message_length {
        msg.truncate(cfg.max_message_length);
        msg.push_str("\n...[truncated]");
    }

    Report { message: msg }
}

fn public_ipv4() -> Option<String> {
    let sock = UdpSocket::bind("0.0.0.0:0").ok()?;
    sock.connect("1.1.1.1:80").ok()?;
    Some(sock.local_addr().ok()?.ip().to_string())
}

fn collect_largest_files(paths: &[String], limit: usize) -> Vec<(u64, String)> {
    let mut all: Vec<(u64, String)> = Vec::new();
    for p in paths {
        let path = Path::new(p);
        if !path.is_dir() {
            continue;
        }
        for entry in WalkDir::new(path).same_file_system(true).into_iter() {
            let entry = match entry {
                Ok(e) => e,
                Err(_) => continue,
            };
            if !entry.file_type().is_file() {
                continue;
            }
            let meta = match entry.metadata() {
                Ok(m) => m,
                Err(_) => continue,
            };
            all.push((meta.len(), entry.path().display().to_string()));
        }
    }
    all.sort_by_key(|item| std::cmp::Reverse(item.0));
    all.truncate(limit);
    all
}

fn human_bytes(n: u64) -> String {
    const UNITS: &[&str] = &["B", "K", "M", "G", "T", "P"];
    let mut v = n as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{n}{}", UNITS[0])
    } else {
        format!("{v:.1}{}", UNITS[i])
    }
}
