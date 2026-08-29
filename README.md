# BytesPulse AV — Security Scanner for HestiaCP

> **English** | [Ελληνικά](#ελληνικά)

---

Continuous security scanner daemon for **HestiaCP** servers.
Monitors every hosted site, detects webshells, malware, compromised CMS core files, C2 connections, crypto drainers, and server misconfigurations.

> **Zero external dependencies.** Written in Go. Runs as a systemd daemon.
> **Read-only by default.** Never modifies site files.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/uninstall.sh | sudo bash
```

---

## Detection methodology

BytesPulse AV combines multiple detection layers:

**Open source threat intelligence** — publicly available databases updated daily, including malicious URL feeds and known malware file hash databases.

**Official CMS checksums** — WordPress core files are verified against the official wordpress.org checksums API. Joomla, Drupal, PrestaShop, OpenCart, and Magento are verified against their official GitHub releases.

**Proprietary pattern library** — built from real incident response on compromised HestiaCP servers. Covers webshells, C2 communication, crypto drainers, authentication bypasses, and persistence mechanisms documented from actual attacks. For security reasons and to maintain detection effectiveness, these patterns are not published.

**Curated hash database** — SHA256 hashes of webshells collected from real compromised servers, merged at runtime with public databases. Not published for the same reasons.

---

## Scan types

| Type | What it checks |
|---|---|
| **Full Scan** | All modules |
| **File Scan** | Webshells, backdoors, obfuscated code, C2 URLs, crypto drainers, polyglot images |
| **Core Integrity** | WordPress/Joomla/Drupal/PrestaShop/OpenCart/Magento vs official checksums |
| **DB Scan** | WordPress database injections, rogue admins |
| **Network** | SSL, DNS changes, IP blacklists, Google Safe Browsing |
| **Hardening** | SSH, fail2ban, PHP version, open ports, cron, .htaccess |

---

## HestiaCP plugin

**Users** (`/list/bpav/`): domain selector, scan buttons, live progress, results, history with download/delete.

**Admin** (Server toolbar → 🛡️ AV Scanner): overview of all users, scan all users at once, settings, API keys.

---

## Email reports

HTML reports (plain text fallback): color-coded by risk, per-site findings with severity, affected files, action recommendations.

---

## Languages

🇬🇧 English · 🇬🇷 Greek · 🇺🇦 Ukrainian · 🇮🇹 Italian · 🇪🇸 Spanish

Language follows HestiaCP UI setting automatically.

---

## Configuration

`/etc/bpav/config.json` — schedule, language, since-date, workers, Google Safe Browsing key, WPVulnDB token.

---

## Severity levels

🔴 **CRITICAL** — Active compromise · 🟠 **HIGH** — Fix urgently · 🟡 **MEDIUM** — Fix when possible · ⚪ **LOW** — Informational · 🟢 **OK** — Clean

---

## Security

- API binds to `127.0.0.1` only
- All actions authenticated via HestiaCP session
- Domain ownership verified before every scan
- Non-admin users can only scan their own domains
- Plugin survives HestiaCP updates via official `post_install.sh` hook

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

## License

GPL-3.0

---

## Credits

Developed by **[BytesPulse](https://bytespulse.gr)**

---
---

# Ελληνικά

> [English](#bytespulse-av--security-scanner-for-hestiacp) | **Ελληνικά**

---

Daemon συνεχούς σάρωσης ασφαλείας για **HestiaCP** servers.
Εντοπίζει webshells, malware, τροποποιημένα core αρχεία CMS, C2 συνδέσεις, crypto drainers και παραμετροποιήσεις server.

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

## Μεθοδολογία Εντοπισμού

**Open source threat intelligence** — δημόσια διαθέσιμα databases που ενημερώνονται καθημερινά.

**Επίσημα CMS checksums** — WordPress μέσω wordpress.org API, Joomla/Drupal/PrestaShop/OpenCart/Magento μέσω επίσημων GitHub releases.

**Proprietary pattern library** — κατασκευάστηκε από πραγματικό incident response σε παραβιασμένους HestiaCP servers. Καλύπτει webshells, C2 επικοινωνία, crypto drainers, authentication bypasses και persistence mechanisms. Για λόγους ασφαλείας και αποτελεσματικότητας δεν δημοσιεύεται.

**Curated hash database** — SHA256 hashes από πραγματικά παραβιασμένα servers, merged με public databases. Επίσης δεν δημοσιεύεται για τους ίδιους λόγους.

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

## Email Reports

HTML reports με χρωματιστό header, per-site ευρήματα και action recommendations.

---

## Γλώσσες

🇬🇧 English · 🇬🇷 Ελληνικά · 🇺🇦 Українська · 🇮🇹 Italiano · 🇪🇸 Español

Η γλώσσα ακολουθεί αυτόματα τις ρυθμίσεις HestiaCP.

---

## Ρυθμίσεις

`/etc/bpav/config.json` — schedule, γλώσσα, since-date, workers, Google Safe Browsing, WPVulnDB.

---

## Επίπεδα Σοβαρότητας

🔴 **CRITICAL** · 🟠 **HIGH** · 🟡 **MEDIUM** · ⚪ **LOW** · 🟢 **OK**

---

## Άδεια

GPL-3.0

---

## Credits

Αναπτύχθηκε από **[BytesPulse](https://bytespulse.gr)**
