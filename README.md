# BytesPulse AV — Security Scanner for HestiaCP

> **English** | [Ελληνικά](#ελληνικά)

---

Continuous security scanner daemon for **HestiaCP** servers.  
Monitors every hosted site, detects webshells, malware, compromised CMS core files, C2 connections, crypto drainers, and server misconfigurations — with a native HestiaCP panel interface and bilingual email reports (EN / EL).

> **Zero external dependencies.** Written in Go. Runs as a systemd daemon.  
> **Read-only by default.** Never modifies site files — only scans and reports.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

After install, open your HestiaCP panel:

- **Users:** `https://YOUR-SERVER:8083/list/bpav/`
- **Admin:** Server → **🛡️ AV Scanner** button in the toolbar

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/uninstall.sh | sudo bash
```

Removes everything: daemon, service, plugin, config, logs, and scan history.

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

1. Exposes a Unix socket at `/run/bpav/bpav.sock` — accessible only by the HestiaCP web process (`hestiaweb` group)
2. Accepts scan jobs from the HestiaCP plugin via the socket
3. Runs scans in the background with configurable parallelism
4. Stores results in `/home/<user>/.bpav/scans/`
5. Sends bilingual email reports on completion

The HestiaCP plugin handles all authentication via the existing HestiaCP session — no separate login required.

---

## What each scan does

| Scan Type | What it checks |
|---|---|
| **Full Scan** | All modules — complete security audit |
| **File Scan** | PHP/JS/HTML files for webshells, backdoors, obfuscated code, C2 URLs, crypto drainers, polyglot images, exposed sensitive files |
| **Core Integrity** | WordPress/Joomla/Drupal/PrestaShop/OpenCart/Magento core files compared against official clean checksums |
| **Network** | SSL certificate validity and expiry, DNS records, Spamhaus/DNSBL blacklist check, Google Safe Browsing |
| **Hardening** | SSH configuration, fail2ban, PHP version, open ports, firewall rules, `.user.ini` |
| **DB Scan** | WordPress database for SQL injections, suspicious options, rogue admin accounts |

---

## What the scanner detects

### Webshells & backdoors
- `eval(base64_decode(...))`, `eval(gzinflate(...))`, `assert($_POST[...])` and all common obfuscation patterns
- Hex-named obfuscated functions (e.g. `_x814a3e63d989()`) — seen in real attacks
- PHP files in `uploads/` directory
- Extra file extensions: `.phar`, `.php7`, `.phtml`, `.php5`
- Polyglot images: `<?php` embedded inside `.jpg`, `.png`, `.gif`, `.webp`
- Must-use plugins (MU plugins) — auto-load and invisible in WP dashboard

### C2 / exfiltration
- Known C2 hosting patterns (Pastebin raw, Discord webhooks, ngrok, etc.)
- Blockchain / crypto drainer RPC endpoints (BSC, Infura, Alchemy, Ankr, Polygon)
- `window.ethereum`, `eth_requestAccounts` — crypto wallet drainer JS
- Dynamic script injection patterns

### WordPress-specific
- Rogue admin accounts created after a specified date
- Plugin list hiding (`add_filter("plugins_list", ...)`) — attacker concealing malicious plugins
- Admin authentication bypass (`wp_set_auth_cookie()` without password check)
- Core checksum failure — any modified WordPress core file

### CMS core integrity (multi-CMS)
Downloads the exact clean version of each CMS from official sources and diffs against the live site:
- WordPress (via WP-CLI checksums against wordpress.org)
- Joomla, Drupal, PrestaShop, OpenCart, Magento (via official GitHub releases)

### Server hardening
- SSH `PasswordAuthentication` enabled (brute-force risk)
- `PermitRootLogin` enabled
- fail2ban not running
- PHP version below recommended
- Suspicious crontab entries
- `.user.ini` with `auto_prepend_file`
- Dangerous `.htaccess` directives

---

## HestiaCP plugin

Integrates natively into HestiaCP — no separate URL or login.

**For users** (`/list/bpav/`):
- Select a domain → run any scan type
- Live progress bar with module-by-module updates
- Results with severity levels (CRITICAL / HIGH / MEDIUM / LOW)
- Scan history with download (JSON) and delete per scan
- Language switcher (EN / EL)

**For admin** (Server toolbar → 🛡️ AV Scanner):
- **Overview tab** — all users, last scan date, risk level
- **Scan Users tab** — scan all users at once or per-user with one click
- **Settings tab** — schedule, language, since-date, workers, Google Safe Browsing key, WPVulnDB token
- **API Keys tab** — manage keys for the BytesPulse Central Panel

---

## Scan results severity

| Level | Meaning |
|---|---|
| 🔴 **CRITICAL** | Active compromise — immediate action required |
| 🟠 **HIGH** | Serious risk — review and fix urgently |
| 🟡 **MEDIUM** | Security concern — fix when possible |
| ⚪ **LOW** | Informational — minor issues or best-practice recommendations |
| 🟢 **OK** | Clean — no issues found in this module |

---

## Files & directories

| Path | Purpose |
|---|---|
| `/usr/local/bin/bpav-daemon` | Main daemon binary |
| `/etc/bpav/config.json` | Daemon configuration |
| `/etc/bpav/admin_token.txt` | Admin API token (keep private) |
| `/etc/bpav/i18n/` | Translation files (EN, EL) |
| `/etc/bpav/hestia-plugin/` | Plugin source (update-proof) |
| `/var/log/bpav/daemon.log` | Daemon log |
| `/run/bpav/bpav.sock` | Unix socket (hestiaweb group, mode 660) |
| `/home/<user>/.bpav/scans/` | Per-user scan results |
| `/etc/systemd/system/bpav.service` | systemd service |
| `/etc/hestiacp/hooks/post_install.sh` | Auto-reinstates plugin after HestiaCP updates |

---

## Configuration

Edit `/etc/bpav/config.json` then restart the daemon:

```bash
sudo systemctl restart bpav
```

| Setting | Default | Description |
|---|---|---|
| `default_language` | `en` | Default language (`en` or `el`) |
| `schedule_day` | `friday` | Day of weekly scheduled scan |
| `schedule_hour` | `6` | Hour of scheduled scan (0–23) |
| `since_date` | 90 days ago | Flag files modified after this date |
| `max_workers` | `2` | Parallel scan workers |
| `google_safe_browsing_key` | _(empty)_ | [Get free key](https://console.cloud.google.com) |
| `wpvulndb_token` | _(empty)_ | WPVulnDB token for plugin CVE checks |

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
- All actions authenticated via HestiaCP session (no separate auth)
- Domain ownership verified via `v-list-web-domain` before every scan
- Plugin files survive HestiaCP updates via the official `post_install.sh` hook
- Scan results stored per-user — no cross-user access possible

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
Παρακολουθεί κάθε hosted site, εντοπίζει webshells, malware, τροποποιημένα core αρχεία CMS, C2 συνδέσεις, crypto drainers και παραμετροποιήσεις server — με native HestiaCP panel και δίγλωσσα email reports (EN / EL).

> **Zero εξωτερικές εξαρτήσεις.** Γραμμένο σε Go. Τρέχει ως systemd daemon.  
> **Read-only by default.** Δεν τροποποιεί ποτέ αρχεία site — μόνο σαρώνει και αναφέρει.

---

## Εγκατάσταση

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
```

Μετά την εγκατάσταση:

- **Χρήστες:** `https://SERVER-ΣΑΣ:8083/list/bpav/`
- **Admin:** Server → κουμπί **🛡️ AV Scanner** στη toolbar

---

## Απεγκατάσταση

```bash
curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/uninstall.sh | sudo bash
```

Αφαιρεί τα πάντα: daemon, service, plugin, config, logs και scan history.

---

## Απαιτήσεις

- Linux server με **HestiaCP**
- Ubuntu 20.04 / 22.04 / 24.04 (amd64 ή arm64)
- Πρόσβαση `root`
- `python3`, `curl`, `unzip` (εγκαθίστανται αυτόματα)
- **WP-CLI** (εγκαθίσταται αυτόματα)

---

## Πώς λειτουργεί

Το BytesPulse AV τρέχει ως background daemon (`bpav.service`) που:

1. Εκθέτει Unix socket στο `/run/bpav/bpav.sock` — προσβάσιμο μόνο από τη διαδικασία web του HestiaCP (group `hestiaweb`)
2. Δέχεται scan jobs από το HestiaCP plugin μέσω socket
3. Εκτελεί σαρώσεις στο background με ρυθμιζόμενο παραλληλισμό
4. Αποθηκεύει αποτελέσματα στο `/home/<user>/.bpav/scans/`
5. Στέλνει δίγλωσσα email reports κατά την ολοκλήρωση

---

## Τι κάνει κάθε σάρωση

| Τύπος | Τι ελέγχει |
|---|---|
| **Πλήρης Σάρωση** | Όλα τα παρακάτω modules |
| **Σάρωση Αρχείων** | PHP/JS/HTML για webshells, backdoors, obfuscated κώδικα, C2 URLs, crypto drainers, polyglot εικόνες |
| **Ακεραιότητα Core** | WordPress/Joomla/Drupal/PrestaShop/OpenCart/Magento σε σύγκριση με επίσημα clean checksums |
| **Δίκτυο** | SSL, DNS, Spamhaus/DNSBL blacklist, Google Safe Browsing |
| **Ασφάλεια Server** | SSH config, fail2ban, PHP version, open ports, firewall, `.user.ini` |
| **Σάρωση Βάσης** | WordPress database για SQL injections, rouge admin λογαριασμούς |

---

## Τι εντοπίζει

### Webshells & backdoors
- `eval(base64_decode(...))`, `eval(gzinflate(...))`, `assert($_POST[...])` και όλα τα συνηθισμένα obfuscation patterns
- Hex-named obfuscated functions (π.χ. `_x814a3e63d989()`) — εμφανίστηκαν σε πραγματικές επιθέσεις
- PHP αρχεία στο `uploads/` directory
- Extra file extensions: `.phar`, `.php7`, `.phtml`, `.php5`
- Polyglot images: `<?php` μέσα σε `.jpg`, `.png`, `.gif`, `.webp`
- Must-use plugins (MU plugins) — φορτώνουν αυτόματα και είναι αόρατα στο WP dashboard

### C2 / exfiltration
- Γνωστά C2 hosting patterns (Pastebin raw, Discord webhooks, ngrok κλπ.)
- Blockchain / crypto drainer RPC endpoints (BSC, Infura, Alchemy, Ankr, Polygon)
- `window.ethereum`, `eth_requestAccounts` — crypto wallet drainer JS
- Dynamic script injection patterns

### WordPress-specific
- Rogue admin λογαριασμοί δημιουργημένοι μετά από συγκεκριμένη ημερομηνία
- Plugin list hiding (`add_filter("plugins_list", ...)`) — επιτιθέμενος κρύβει κακόβουλα plugins
- Admin authentication bypass (`wp_set_auth_cookie()` χωρίς έλεγχο password)
- Core checksum failure — οποιοδήποτε τροποποιημένο WordPress core αρχείο

### Ακεραιότητα CMS (multi-CMS)
Κατεβάζει την ακριβή clean έκδοση κάθε CMS από επίσημες πηγές και κάνει diff:
- WordPress (μέσω WP-CLI checksums)
- Joomla, Drupal, PrestaShop, OpenCart, Magento (μέσω επίσημων GitHub releases)

### Hardening server
- SSH `PasswordAuthentication` ενεργό
- `PermitRootLogin` ενεργό
- fail2ban που δεν τρέχει
- PHP version κάτω από recommended
- Ύποπτες crontab εγγραφές
- `.user.ini` με `auto_prepend_file`
- Επικίνδυνες `.htaccess` οδηγίες

---

## HestiaCP plugin

**Για χρήστες** (`/list/bpav/`):
- Επιλογή domain → εκτέλεση οποιουδήποτε τύπου σάρωσης
- Live progress bar με ενημερώσεις ανά module
- Αποτελέσματα με επίπεδα σοβαρότητας (CRITICAL / HIGH / MEDIUM / LOW)
- Ιστορικό σαρώσεων με download (JSON) και διαγραφή ανά σάρωση
- Language switcher (EN / EL)

**Για admin** (Server toolbar → 🛡️ AV Scanner):
- **Tab Επισκόπηση** — όλοι οι users, τελευταία σάρωση, επίπεδο κινδύνου
- **Tab Σάρωση Χρηστών** — σάρωση όλων ή ανά χρήστη με ένα κλικ
- **Tab Ρυθμίσεις** — schedule, γλώσσα, since-date, workers, API keys
- **Tab API Keys** — διαχείριση keys για το BytesPulse Central Panel

---

## Επίπεδα σοβαρότητας

| Επίπεδο | Σημασία |
|---|---|
| 🔴 **CRITICAL** | Ενεργή παραβίαση — απαιτείται άμεση δράση |
| 🟠 **HIGH** | Σοβαρός κίνδυνος — ελέγξτε και διορθώστε άμεσα |
| 🟡 **MEDIUM** | Θέμα ασφαλείας — διορθώστε όταν είναι δυνατό |
| ⚪ **LOW** | Πληροφοριακό — μικρά θέματα ή best practices |
| 🟢 **OK** | Καθαρό — δεν βρέθηκαν προβλήματα |

---

## Αρχεία & directories

| Path | Σκοπός |
|---|---|
| `/usr/local/bin/bpav-daemon` | Κύριο binary |
| `/etc/bpav/config.json` | Ρυθμίσεις daemon |
| `/etc/bpav/admin_token.txt` | Admin API token (κρατήστε ιδιωτικό) |
| `/etc/bpav/i18n/` | Αρχεία μεταφράσεων (EN, EL) |
| `/etc/bpav/hestia-plugin/` | Plugin source (update-proof) |
| `/var/log/bpav/daemon.log` | Log daemon |
| `/run/bpav/bpav.sock` | Unix socket (group hestiaweb, mode 660) |
| `/home/<user>/.bpav/scans/` | Αποτελέσματα σαρώσεων ανά χρήστη |
| `/etc/systemd/system/bpav.service` | systemd service |
| `/etc/hestiacp/hooks/post_install.sh` | Επαναφορά plugin μετά από HestiaCP updates |

---

## Ρυθμίσεις

Επεξεργαστείτε το `/etc/bpav/config.json` και επανεκκινήστε:

```bash
sudo systemctl restart bpav
```

| Ρύθμιση | Default | Περιγραφή |
|---|---|---|
| `default_language` | `en` | Γλώσσα email/UI (`en` ή `el`) |
| `schedule_day` | `friday` | Ημέρα εβδομαδιαίας σάρωσης |
| `schedule_hour` | `6` | Ώρα σάρωσης (0–23) |
| `since_date` | 90 μέρες πριν | Σημαδεύει αρχεία τροποποιημένα μετά από αυτή |
| `max_workers` | `2` | Παράλληλοι workers |
| `google_safe_browsing_key` | _(κενό)_ | [Δωρεάν key](https://console.cloud.google.com) |
| `wpvulndb_token` | _(κενό)_ | WPVulnDB token για CVE checks plugins |

---

## Ενημέρωση μόνο του daemon

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

## Σημειώσεις ασφαλείας

- Το daemon API κάνει bind μόνο στο `127.0.0.1` — δεν εκτίθεται ποτέ στο internet
- Όλες οι ενέργειες ελέγχονται μέσω HestiaCP session
- Η κυριότητα domain επαληθεύεται μέσω `v-list-web-domain` πριν από κάθε σάρωση
- Τα αρχεία plugin επιβιώνουν από HestiaCP updates μέσω του επίσημου `post_install.sh` hook
- Τα αποτελέσματα αποθηκεύονται ανά χρήστη — χωρίς cross-user πρόσβαση

---

## Άδεια

GPL-3.0

---

## Credits

Αναπτύχθηκε από **[BytesPulse](https://bytespulse.gr)**  
Βασισμένο σε incident response από πραγματικές παραβιάσεις HestiaCP servers.
