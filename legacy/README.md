# Legacy bash implementation (deprecated)

This directory contains the original bash version of the resource monitor.
It is **deprecated** and kept only for historical reference / comparison.

The active implementation is the Rust binary `pingmeup` at the repository
root. Pre-built binaries are published as GitHub Release artifacts on tags.

## Why deprecated

- Forks 5+ external utilities (`free`, `df`, `ps`, `find`, `du`, `awk`,
  `curl`) per run; Rust version makes zero subprocess calls.
- Higher memory footprint and CPU time (see commit history for benchmarks:
  ~3-15× slower wall-clock and 8-20× higher CPU time on the disk-walk path).
- Harder to package, distribute, and pin to a known-good version.
- No type checking on config values; silent fallbacks to defaults on typos.

## Files

- `monitor-me.sh` — bash CPU/RAM/disk monitor, last working version.

## Migrating to `pingmeup`

The legacy `.env` format maps directly to the new TOML config. See
`config.example.toml` at the repo root for the equivalent fields.
