# BytesPulse AV — Security Scanner for HestiaCP (Private Repository)

> **English** | [Ελληνικά](#ελληνικά)

---

## Detection Engine — Sources & Methodology

### Our own pattern library (closed, proprietary)

Built from real incident response on compromised HestiaCP servers. Every pattern has a documented origin from a real attack.

**Tier 1 — High confidence (almost always malicious):**
- `eval(base64_decode(...))`, `eval(gzinflate(...))`, `eval(str_rot13(...))`
- `assert($_POST[...])`, `assert($_GET[...])`
- `shell_exec()`, `passthru()`, `proc_open()`, `pcntl_exec()`
- `create_function()` — deprecated PHP backdoor technique
- `php://input` — legitimate only in `xmlrpc.php` (whitelisted)
- Hex-named obfuscated functions: `_x[0-9a-f]{8,}()` — documented in cbi.gr attack (2026)
- C2 fetch+exec: `file_get_contents($url); eval($content)` — documented in cbi.gr attack

**Tier 2 — Suspicious when combined with user input:**
- `eval|assert|base64_decode|gzinflate|gzuncompress|gzdecode|str_rot13` + `$_POST|$_GET|$_REQUEST|$_COOKIE`

**Tier 3 — Broad patterns (low priority, high false-positive rate):**
- Same functions without user input context — informational only

**C2 / Exfiltration patterns (our research):**
- Pastebin raw, Discord webhooks, ngrok, ngrok-free.app
- Blockchain RPC endpoints: BSC testnet, Infura, Alchemy, Ankr, Polygon — from cbi.gr crypto drainer analysis
- `window.ethereum`, `eth_requestAccounts`, `wallet_switchEthereumChain` — crypto drainer JS
- Dynamic script injection, fake overlay/phishing injection

**WordPress-specific patterns (our research):**
- Plugin list hiding: `add_filter("plugins_list", ...)` — from cbi.gr attack (hides malicious plugins from WP dashboard)
- Admin auth bypass: `wp_set_auth_cookie()` without password check, `?al=true` backdoor — from cbi.gr attack
- MU-plugin malware: hex-named functions (`function _ea_90225d92()`), C2 fetch+eval — from cbi.gr attack
- Hidden admin: `pre_user_query` filter removing admin from user lists — from bikerspirit.net attack

**JS Obfuscation patterns:**
- `eval(atob(...))`, `eval(unescape(...))`
- `String.fromCharCode(...)` with long sequences
- Dynamic script injection: `createElement + appendChild`
- Fake overlay injection: `document.body.innerHTML =`

**Cloaking patterns:**
- Bot-UA detection: `HTTP_USER_AGENT` + Googlebot check in same function
- Combined with external fetch (`curl_init`, `file_get_contents`) = cloaking

**SEO spam patterns:**
- Casino, poker, online gambling keywords
- Pharmaceutical spam (viagra, cialis, tramadol)
- Payday loans, replica goods

**Mailer/spam script patterns:**
- `mail()` with user input parameters
- `fsockopen` to port 25
- Suspicious X-Mailer, Bcc, From headers from user input

**Hardcoded false positive whitelists:**
- `xmlrpc.php` — excluded from Tier1 scan (uses `php://input` legitimately)
- `.min.js` files — excluded from JS obfuscation scan (minification ≠ obfuscation)
- `wp-includes/js/`, `wp-includes/build/`, `wp-admin/js/` — excluded from JS/C2 scan
- `wp-includes/php-ai-client/` — WP 7.0 core AI Client (merged Feb 2026, changeset 61700)
- `wp-config-sample.php` — commonly deleted by sysadmins, not a security issue
- `/wp-includes/`, `/wp-admin/` — excluded from mailer scan (contain legitimate PHPMailer)

---

### Open source threat intelligence (integrated, updated daily)

| Source | What we use | Update frequency |
|---|---|---|
| **URLhaus** (abuse.ch) | Malicious URLs and C2 domain list | Continuous (we fetch every 24h) |
| **MalwareBazaar** (abuse.ch) | SHA256 hashes of known malware files | Recent samples feed (we fetch every 24h) |

Feeds stored at `/etc/bpav/feeds/`, merged in memory with our own patterns. Atomic updates (temp file → rename), zero downtime. Background goroutine refreshes every 24h.

---

### Official CMS checksums (authoritative)

| CMS | Source | Method |
|---|---|---|
| **WordPress** | wordpress.org checksums API | `wp core verify-checksums` — compares every core file |
| **Joomla** | GitHub releases (joomla/joomla-cms) | Download clean version → diff → delete |
| **Drupal** | GitHub releases (drupal/drupal) | Download clean version → diff → delete |
| **PrestaShop** | GitHub releases (PrestaShop/PrestaShop) | Download clean version → diff → delete |
| **OpenCart** | GitHub releases (opencart/opencart) | Download clean version → diff → delete |
| **Magento** | GitHub releases (magento/magento2) | Download clean version → diff → delete |

---

### Our own curated hash database (closed, not published)

`/etc/bpav/known_shells.sha256` — curated SHA256 hashes of webshells we have collected from real compromised servers. Merged with MalwareBazaar at runtime. **Not published** for security reasons — publishing gives attackers a checklist of what to avoid.

---

### Network & reputation checks

| Check | Source | Notes |
|---|---|---|
| **Spamhaus ZEN** | zen.spamhaus.org | DNS-based blacklist (DNSBL) lookup |
| **Google Safe Browsing** | Google API v4 | Optional — requires API key in config |
| **SSL expiry** | Direct TLS connection | No external service needed |
| **DNS change detection** | Our own baseline system | First scan saves baseline, subsequent scans diff |

---

## Architecture decisions

| Decision | Reason |
|---|---|
| Go daemon, zero external deps | No runtime dependencies, single binary, cross-architecture |
| Unix socket (not TCP) | Cannot be accidentally exposed to the internet |
| Socket group `hestiaweb` + mode 660 | Only HestiaCP PHP processes can reach the daemon |
| API binds to `127.0.0.1` | External REST API never exposed without explicit config |
| `ProtectSystem=false` in systemd | Daemon needs write access to `/home/*/` for scan storage |
| `ExecStartPost` for socket permissions | Ensures correct permissions after every daemon restart |
| Plugin in `/etc/bpav/hestia-plugin/` | Outside HestiaCP dirs — survives `apt upgrade hestia` |
| `post_install.sh` hook | Official HestiaCP mechanism — runs after every HestiaCP update |
| No `prevent_csrf.php` patching | EventSource sends same-origin Referer; `ajax.php` validates token independently |
| Hex-encoded test fixtures | Windows Defender quarantines files containing webshell literals, breaking `git clone` |
| Feeds: atomic tmp→rename | Never corrupt feed state during update |
| Per-user `prefs.json` | Language preference stored per-user, synced from HestiaCP session |

---

## Known attack post-mortems documented in codebase

### cbi.gr crypto drainer (2026)
- **Entry:** Vulnerable plugin or leaked credentials (July 21)
- **Persistence:** 2x WP plugins (`wp-helper-bb0b4a`, `wp-helper-d7378c`) + MU-plugin (`ea_90225d92.php`) + 3x theme injections
- **Payload:** Fake Google reCAPTCHA overlay → BSC testnet RPC → crypto wallet drainer
- **Evasion:** `add_filter("plugins_list", ...)` hides plugins from WP dashboard; XOR obfuscation with key `ykmy`
- **Patterns added:** `PluginListHide`, `AdminBypass`, `MUPluginMalware`, `_x[0-9a-f]{8,}()`, blockchain RPC C2

### bikerspirit.net wp2shell CVE chain (origin of this project)
- **Entry:** wp2shell CVE chain attack
- **Persistence:** `pre_user_query` filter hiding admin account from user list
- **Payload:** Remote code execution via C2
- **Patterns added:** `HiddenAdminFilter`, `CloakingUA`, `CloakingFetch`, full wp2shell scanner

---

## False positives policy

Every pattern addition requires:
1. Documented real-world origin (not theoretical)
2. A corresponding test in `files_test.go` or `wp2shell_test.go`
3. A whitelist entry for any known-legitimate use of the same pattern

Hex-encode any literal payload in test fixtures — Windows Defender quarantines files containing webshell signatures.

---

## Languages supported

| Code | Language | Status |
|---|---|---|
| `en` | English | ✅ Complete (reference) |
| `el` | Ελληνικά (Greek) | ✅ Complete |
| `uk` | Українська (Ukrainian) | ✅ Core strings — community can expand |
| `it` | Italiano (Italian) | ✅ Core strings |
| `es` | Español (Spanish) | ✅ Core strings |

To add a language: place `/etc/bpav/i18n/<lang>.json` with translations — daemon loads it automatically on next restart.

---

## Changelog highlights

| Version | What changed |
|---|---|
| v1.1.x | HestiaCP plugin rebuilt — standalone pages, no core file patching |
| v1.1.x | Admin panel: Overview / Scan Users / Settings / API Keys tabs |
| v1.1.x | Multi-CMS integrity (Joomla, Drupal, PrestaShop, OpenCart, Magento) |
| v1.1.x | URLhaus + MalwareBazaar daily feed sync |
| v1.1.x | 5-language support (EN/EL/UK/IT/ES) with auto-sync from HestiaCP |
| v1.1.x | HTML email reports (multipart/alternative, color-coded, per-site findings) |
| v1.1.x | MU-plugin scan with elevated CRITICAL severity |
| v1.1.x | cbi.gr attack patterns: PluginListHide, AdminBypass, MUPluginMalware, blockchain RPC |
| v1.1.x | Domain filter: per-domain scan (not full-user scan) when domain specified |
| v1.1.x | Hardening deduplication: SSH/fail2ban/crontab run once per scan |
| v1.1.x | Hex-encoded test fixtures (prevent Windows Defender quarantine) |
| v1.0.0 | Initial release — Go daemon, wp2shell scanner, WordPress integrity |

---

> ℹ️ For the public-facing README see the `bytespulse-av-releases` repository.

---
---

# Ελληνικά

## Μηχανή Εντοπισμού — Πηγές & Μεθοδολογία

### Δική μας βιβλιοθήκη patterns (κλειστή, proprietary)

Κατασκευάστηκε από πραγματικό incident response σε παραβιασμένους HestiaCP servers. Κάθε pattern έχει τεκμηριωμένη προέλευση από πραγματική επίθεση.

**Tier 1 — Υψηλή βεβαιότητα (σχεδόν πάντα κακόβουλο):**
- `eval(base64_decode(...))`, `eval(gzinflate(...))`, `eval(str_rot13(...))`
- `assert($_POST[...])`, `shell_exec()`, `passthru()`, `proc_open()`
- Hex-named obfuscated functions: `_x[0-9a-f]{8,}()` — από επίθεση cbi.gr (2026)
- C2 fetch+exec: `file_get_contents($url); eval($content)` — από επίθεση cbi.gr

**Patterns WordPress (δική μας έρευνα):**
- Plugin list hiding: `add_filter("plugins_list", ...)` — από επίθεση cbi.gr
- Admin auth bypass: `wp_set_auth_cookie()` χωρίς έλεγχο password — από επίθεση cbi.gr
- MU-plugin malware: hex-named functions, C2 fetch+eval — από επίθεση cbi.gr
- Hidden admin: `pre_user_query` filter — από επίθεση bikerspirit.net

**Γνωστά false positives — Whitelist:**
- `xmlrpc.php` — εξαιρείται από Tier1 (χρησιμοποιεί `php://input` legitimately)
- `.min.js` αρχεία — εξαιρούνται από JS obfuscation scan
- `wp-includes/php-ai-client/` — WP 7.0 core AI Client (merged Feb 2026)
- `wp-config-sample.php` — συχνά σβήνεται από sysadmins

---

### Open source threat intelligence (ενσωματωμένο, daily update)

| Πηγή | Τι χρησιμοποιούμε | Συχνότητα |
|---|---|---|
| **URLhaus** (abuse.ch) | Κακόβουλα URLs και C2 domains | Κάθε 24 ώρες |
| **MalwareBazaar** (abuse.ch) | SHA256 hashes γνωστών malware | Κάθε 24 ώρες |

---

### Επίσημα CMS checksums (αυθεντικά)

| CMS | Πηγή |
|---|---|
| **WordPress** | wordpress.org checksums API μέσω WP-CLI |
| **Joomla, Drupal, PrestaShop, OpenCart, Magento** | Επίσημα GitHub releases |

---

### Δική μας curated hash database (κλειστή, δεν δημοσιεύεται)

`/etc/bpav/known_shells.sha256` — SHA256 hashes webshells που έχουμε συλλέξει από πραγματικά παραβιασμένα servers. **Δεν δημοσιεύεται** για λόγους ασφαλείας — η δημοσίευση δίνει στους επιτιθέμενους checklist για να αποφύγουν.

---

### Δικτυακοί / reputation έλεγχοι

| Έλεγχος | Πηγή |
|---|---|
| **Spamhaus ZEN** | zen.spamhaus.org (DNSBL) |
| **Google Safe Browsing** | Google API v4 (προαιρετικό) |
| **SSL expiry** | Απευθείας TLS σύνδεση |
| **DNS change detection** | Δικό μας baseline σύστημα |

---

## Post-mortems επιθέσεων στον κώδικα

### cbi.gr crypto drainer (2026)
- Fake reCAPTCHA → BSC testnet RPC → crypto wallet drainer
- Εισαγωγή: `PluginListHide`, `AdminBypass`, `MUPluginMalware`, blockchain RPC C2

### bikerspirit.net wp2shell CVE chain (αρχή του project)
- `pre_user_query` filter κρύβει admin από τη λίστα χρηστών
- Εισαγωγή: `HiddenAdminFilter`, `CloakingUA`, `CloakingFetch`, wp2shell scanner

---

> ℹ️ Για το public README δείτε το repository `bytespulse-av-releases`.
