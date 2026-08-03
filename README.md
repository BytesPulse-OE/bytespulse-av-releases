# BytesPulse AV

Security Scanner Daemon for HestiaCP servers.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

## Requirements

- HestiaCP v1.7+
- Ubuntu 20.04 / 22.04 / 24.04
- wp-cli (auto-installed if missing)
- root access

## What it does

- Scans all WordPress and non-WordPress sites for malware
- Detects web shells, cloaking code, SEO spam, database injections
- Checks SSL certificates, DNS changes, blacklists
- Audits server hardening (SSH, fail2ban, PHP versions)
- Sends email reports to each HestiaCP user
- Provides a UI inside HestiaCP panel

## Support

https://bytespulse.gr
