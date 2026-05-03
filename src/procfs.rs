use std::ffi::CString;
use std::fs;
use std::io;
use std::mem::MaybeUninit;
use std::time::Duration;

pub fn cpu_usage() -> io::Result<f64> {
    let (idle1, total1) = cpu_snapshot()?;
    std::thread::sleep(Duration::from_millis(500));
    let (idle2, total2) = cpu_snapshot()?;
    let total_diff = total2.saturating_sub(total1);
    let idle_diff = idle2.saturating_sub(idle1);
    if total_diff == 0 {
        return Ok(0.0);
    }
    Ok(((total_diff - idle_diff) as f64 * 100.0) / total_diff as f64)
}

fn cpu_snapshot() -> io::Result<(u64, u64)> {
    let s = fs::read_to_string("/proc/stat")?;
    let line = s
        .lines()
        .next()
        .ok_or_else(|| io::Error::other("empty /proc/stat"))?;
    let nums: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .filter_map(|t| t.parse::<u64>().ok())
        .collect();
    if nums.len() < 4 {
        return Err(io::Error::other("malformed /proc/stat"));
    }
    let user = nums[0];
    let nice = nums[1];
    let system = nums[2];
    let idle = nums[3];
    let iowait = nums.get(4).copied().unwrap_or(0);
    let irq = nums.get(5).copied().unwrap_or(0);
    let softirq = nums.get(6).copied().unwrap_or(0);
    let steal = nums.get(7).copied().unwrap_or(0);
    let total = user + nice + system + idle + iowait + irq + softirq + steal;
    Ok((idle + iowait, total))
}

pub fn ram_usage_percent() -> io::Result<f64> {
    let (total, available) = mem_total_available()?;
    if total == 0 {
        return Ok(0.0);
    }
    let used = total.saturating_sub(available);
    Ok((used as f64 * 100.0) / total as f64)
}

fn mem_total_available() -> io::Result<(u64, u64)> {
    let s = fs::read_to_string("/proc/meminfo")?;
    let mut total = 0u64;
    let mut available = 0u64;
    for line in s.lines() {
        if let Some(rest) = line.strip_prefix("MemTotal:") {
            total = parse_kb(rest);
        } else if let Some(rest) = line.strip_prefix("MemAvailable:") {
            available = parse_kb(rest);
        }
    }
    Ok((total, available))
}

fn parse_kb(s: &str) -> u64 {
    s.split_whitespace()
        .next()
        .and_then(|t| t.parse().ok())
        .unwrap_or(0)
}

pub fn disk_usage_percent(path: &str) -> io::Result<f64> {
    let c = CString::new(path).map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
    let mut sv: MaybeUninit<libc::statvfs> = MaybeUninit::uninit();
    let r = unsafe { libc::statvfs(c.as_ptr(), sv.as_mut_ptr()) };
    if r != 0 {
        return Err(io::Error::last_os_error());
    }
    let sv = unsafe { sv.assume_init() };
    let total = sv.f_blocks;
    let avail = sv.f_bavail;
    if total == 0 {
        return Ok(0.0);
    }
    let used = total.saturating_sub(avail);
    Ok((used as f64 * 100.0) / total as f64)
}

pub struct Proc {
    pub pid: u32,
    pub comm: String,
    pub cpu_pct: f64,
    pub mem_pct: f64,
}

pub fn top_processes(by_cpu: bool, n: usize) -> io::Result<Vec<Proc>> {
    let clk_tck = unsafe { libc::sysconf(libc::_SC_CLK_TCK) } as f64;
    let pagesize = unsafe { libc::sysconf(libc::_SC_PAGESIZE) } as u64;
    let uptime = read_uptime()?;
    let (total_mem_kb, _) = mem_total_available()?;

    let mut procs = Vec::with_capacity(256);
    for entry in fs::read_dir("/proc")? {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };
        let name = entry.file_name();
        let name_str = match name.to_str() {
            Some(s) => s,
            None => continue,
        };
        let pid: u32 = match name_str.parse() {
            Ok(p) => p,
            Err(_) => continue,
        };
        let stat_path = entry.path().join("stat");
        let stat = match fs::read_to_string(&stat_path) {
            Ok(s) => s,
            Err(_) => continue,
        };
        let close = match stat.rfind(')') {
            Some(i) => i,
            None => continue,
        };
        let open = match stat.find('(') {
            Some(i) => i,
            None => continue,
        };
        if close <= open {
            continue;
        }
        let comm = stat[open + 1..close].to_string();
        let after = match stat.get(close + 2..) {
            Some(s) => s,
            None => continue,
        };
        let fields: Vec<&str> = after.split_whitespace().collect();
        if fields.len() < 22 {
            continue;
        }
        let utime: u64 = fields[11].parse().unwrap_or(0);
        let stime: u64 = fields[12].parse().unwrap_or(0);
        let starttime: u64 = fields[19].parse().unwrap_or(0);
        let rss_pages: u64 = fields[21].parse().unwrap_or(0);

        let total_ticks = (utime + stime) as f64;
        let elapsed = uptime - (starttime as f64 / clk_tck);
        let cpu_pct = if elapsed > 0.0 {
            (total_ticks / clk_tck) / elapsed * 100.0
        } else {
            0.0
        };
        let rss_kb = rss_pages * pagesize / 1024;
        let mem_pct = if total_mem_kb > 0 {
            (rss_kb as f64 * 100.0) / total_mem_kb as f64
        } else {
            0.0
        };

        procs.push(Proc {
            pid,
            comm,
            cpu_pct,
            mem_pct,
        });
    }

    procs.sort_by(|a, b| {
        let av = if by_cpu { a.cpu_pct } else { a.mem_pct };
        let bv = if by_cpu { b.cpu_pct } else { b.mem_pct };
        bv.partial_cmp(&av).unwrap_or(std::cmp::Ordering::Equal)
    });
    procs.truncate(n);
    Ok(procs)
}

fn read_uptime() -> io::Result<f64> {
    let s = fs::read_to_string("/proc/uptime")?;
    Ok(s.split_whitespace()
        .next()
        .and_then(|t| t.parse().ok())
        .unwrap_or(0.0))
}
