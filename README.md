# BytesPulse AV — Security Scanner for HestiaCP

> **English** | [Ελληνικά](#ελληνικά)

---

Continuous security scanner daemon for **HestiaCP** servers.
Monitors every hosted site, detects webshells, malware, compromised CMS core files, C2 connections, crypto drainers, and server misconfigurations — with a native HestiaCP panel interface, multilingual HTML email reports, and daily-updated threat intelligence.

> **Zero external dependencies.** Written in Go. Runs as a systemd daemon.
> **Read-only by default.** Never modifies site files — only scans and reports.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

After install:

- **Users:** `https://YOUR-SERVER:8083/list/bpav/`
- **Admin:** Server dashboard → **🛡️ AV Scanner** button in the toolbar

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/uninstall.sh | sudo bash
```

Removes everything: daemon, service, plugin, config, logs, and scan history from all users.

---

## Requirements

- Linux server running **HestiaCP**
- Ubuntu 20.04 / 22.04 / 24.04 (amd64 or arm64)
- `root` access
- `python3`, `curl`, `unzip` (auto-installed if missing)
- **WP-CLI** (auto-installed if missing)

---

## How it works

BytesPulse AV runs as a background daemon (`bpav.service`) that:

1. Exposes a Unix socket at `/run/bpav/bpav.sock` — accessible only by the HestiaCP web process (`hestiaweb` group, mode 660)
2. Accepts scan jobs from the HestiaCP plugin via the socket
3. Runs scans in the background with configurable parallelism
4. Stores results in `/home/<user>/.bpav/scans/`
5. Sends multilingual HTML email reports on completion

All authentication is handled via the existing HestiaCP session — no separate login required.
Domain ownership is verified before every scan — users can only scan their own domains.

---

## What each scan does

| Scan Type | What it checks |
|---|---|
| **Full Scan** | All modules — complete security audit |
| **File Scan** | PHP/JS/HTML files for webshells, backdoors, obfuscated code, C2 URLs, crypto drainers, polyglot images |
| **Core Integrity** | WordPress/Joomla/Drupal/PrestaShop/OpenCart/Magento core files vs official clean checksums |
| **DB Scan** | WordPress database for SQL injections, suspicious options, rogue admin accounts |
| **Network** | SSL certificate validity, DNS changes, IP blacklist check, Google Safe Browsing |
| **Hardening** | SSH configuration, fail2ban, PHP version, open ports, firewall rules, `.user.ini` |

---

## Detection methodology

BytesPulse AV uses a layered detection approach:

**Open source threat intelligence** — publicly available databases updated daily, including malicious URL feeds and known malware file hash databases.

**Official CMS checksums** — WordPress core files verified against the official wordpress.org checksums API. Joomla, Drupal, PrestaShop, OpenCart, and Magento verified against their official GitHub releases.

**Proprietary pattern library** — built from real incident response on compromised HestiaCP servers. Covers webshells, C2 communication, crypto drainers, authentication bypasses, and persistence mechanisms. For security reasons and to maintain detection effectiveness, these patterns are not published.

**Curated hash database** — SHA256 hashes of webshells collected from real compromised servers. Not published for the same reasons.

---

## HestiaCP plugin

**For users** (`/list/bpav/`):
- Select a domain → run any scan type
- Live progress bar with module-by-module updates
- Results with severity levels (CRITICAL / HIGH / MEDIUM / LOW)
- Scan history with per-scan download (JSON) and delete
- Language follows HestiaCP UI setting automatically

**For admin** (Server toolbar → 🛡️ AV Scanner):

| Tab | Content |
|---|---|
| **Overview** | All users, last scan date, risk level |
| **Scan Users** | Scan all users or per-user (Full/File/DB/Core/Network/Hardening) |
| **Settings** | Schedule, language, since-date, workers, optional API keys, mail config |
| **API Keys** | Manage keys for the BytesPulse Central Panel |

---

## Email reports

Scan results are emailed as **HTML reports** (with plain text fallback):

- Color-coded header based on risk level (green → red)
- Summary: Sites / Critical / High / Medium counts
- Per-site findings with severity, affected files, and code lines
- Action recommendation per site: 🚨 Urgent / ⚠️ Review / ✅ OK

---

## Multilingual support

| Code | Language |
|---|---|
| `en` | 🇬🇧 English |
| `el` | 🇬🇷 Ελληνικά |
| `uk` | 🇺🇦 Українська |
| `it` | 🇮🇹 Italiano |
| `es` | 🇪🇸 Español |

Language follows the HestiaCP UI setting automatically.

---

## Scan results severity

| Level | Meaning |
|---|---|
| 🔴 **CRITICAL** | Active compromise — immediate action required |
| 🟠 **HIGH** | Serious risk — review and fix urgently |
| 🟡 **MEDIUM** | Security concern — fix when possible |
| ⚪ **LOW** | Informational — minor issues or best-practice recommendations |
| 🟢 **OK** | Clean — no issues found |

---

## Configuration

Edit `/etc/bpav/config.json` then restart:

```bash
sudo systemctl restart bpav
```

| Setting | Default | Description |
|---|---|---|
| `default_language` | `en` | Default language (`en`, `el`, `uk`, `it`, `es`) |
| `schedule_day` | `friday` | Day of weekly scheduled scan |
| `schedule_hour` | `6` | Hour of scheduled scan (0–23) |
| `since_date` | 90 days ago | Flag files modified after this date |
| `max_workers` | `2` | Parallel scan workers |
| `google_safe_browsing_key` | _(empty)_ | [Get free key →](https://console.cloud.google.com) |
| `wordfence_api_key` | _(empty)_ | [Get free key →](https://www.wordfence.com/threat-intel/) |
| `mail_from` | _(empty)_ | Email sender address |

---

## Update daemon only

```bash
sudo systemctl stop bpav
ARCH=$(dpkg --print-architecture 2>/dev/null || echo amd64)
sudo curl -fsSL https://github.com/BytesPulse-OE/bytespulse-av-releases/releases/latest/download/bpav-daemon-linux-${ARCH} \
  -o /usr/local/bin/bpav-daemon
sudo chmod +x /usr/local/bin/bpav-daemon
sudo bash /etc/hestiacp/hooks/post_install.sh
sudo systemctl start bpav
```

---

## Security notes

- Daemon API binds to `127.0.0.1` only — never exposed to the internet
- All actions authenticated via HestiaCP session
- Domain ownership verified before every scan
- Non-admin users can only scan their own domains
- Plugin files survive HestiaCP updates via the official `post_install.sh` hook

---

## License

GPL-3.0

---

## Credits

Developed by **[BytesPulse](https://bytespulse.gr)**
Based on incident response from real-world HestiaCP server compromises.

---
---

# Ελληνικά

> [English](#bytespulse-av--security-scanner-for-hestiacp) | **Ελληνικά**

---

Daemon συνεχούς σάρωσης ασφαλείας για **HestiaCP** servers.
Εντοπίζει webshells, malware, τροποποιημένα core αρχεία CMS, C2 συνδέσεις, crypto drainers και παραμετροποιήσεις server — με native HestiaCP panel, πολύγλωσσα HTML email reports και καθημερινή ενημέρωση threat intelligence.

---

## Εγκατάσταση

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

Μετά: **Χρήστες** `https://SERVER:8083/list/bpav/` · **Admin** Server → 🛡️ AV Scanner

---

## Απεγκατάσταση

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/uninstall.sh | sudo bash
```

---

## Τύποι Σάρωσης

| Τύπος | Τι ελέγχει |
|---|---|
| **Πλήρης** | Όλα τα modules |
| **Αρχεία** | Webshells, backdoors, obfuscated κώδικας, C2 URLs, crypto drainers |
| **Ακεραιότητα Core** | CMS vs επίσημα checksums |
| **Βάση Δεδομένων** | SQL injections, rouge admins |
| **Δίκτυο** | SSL, DNS, IP blacklists, Google Safe Browsing |
| **Ασφάλεια Server** | SSH, fail2ban, PHP, open ports, cron |

---

## Μεθοδολογία Εντοπισμού

**Open source threat intelligence** — δημόσια διαθέσιμα databases που ενημερώνονται καθημερινά.

**Επίσημα CMS checksums** — WordPress μέσω wordpress.org API, άλλα CMS μέσω επίσημων GitHub releases.

**Proprietary pattern library** — κατασκευάστηκε από πραγματικό incident response σε παραβιασμένους HestiaCP servers. Για λόγους ασφαλείας δεν δημοσιεύεται.

**Curated hash database** — SHA256 hashes από πραγματικά παραβιασμένα servers. Επίσης δεν δημοσιεύεται.

---

## Email Reports

HTML reports με χρωματιστό header, per-site ευρήματα και action recommendations: 🚨 Urgent / ⚠️ Review / ✅ OK

---

## Πολύγλωσση Υποστήριξη

🇬🇧 English · 🇬🇷 Ελληνικά · 🇺🇦 Українська · 🇮🇹 Italiano · 🇪🇸 Español

---

## Επίπεδα Σοβαρότητας

🔴 **CRITICAL** · 🟠 **HIGH** · 🟡 **MEDIUM** · ⚪ **LOW** · 🟢 **OK**

---

## Άδεια

GPL-3.0

---

## Credits

Αναπτύχθηκε από **[BytesPulse](https://bytespulse.gr)**
Βασισμένο σε incident response από πραγματικές παραβιάσεις HestiaCP servers.
