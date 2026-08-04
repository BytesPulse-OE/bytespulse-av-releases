# BytesPulse AV

Security Scanner Daemon for HestiaCP servers.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

## Requirements

- HestiaCP v1.7+
- Ubuntu 20.04 / 22.04 / 24.04
- Root access

## What it does

- Scans WordPress, Joomla, Drupal, PrestaShop, OpenCart, Magento sites
- Detects web shells, cloaking, SEO spam, database injections
- CMS core integrity check (download clean → diff → delete)
- SSL, DNS, DNSBL, Google Safe Browsing checks
- Server hardening audit (SSH, fail2ban, PHP versions, crontab)
- Email reports in Greek and English
- HestiaCP panel integration

## Support

https://bytespulse.gr
