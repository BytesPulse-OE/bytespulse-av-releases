# BytesPulse AV

Security Scanner Daemon for HestiaCP servers.
ImunifyAV/Sucuri-equivalent built in Go — zero external dependencies.

---

## Features

| Category | What it scans |
|---|---|
| **File** | PHP shells (Tier1/Tier2/Tier3), cloaking, SEO spam, C2 URLs, polyglot images, .htaccess abuse, user.ini, exposed backups, SHA256 shell hash match |
| **Database** | wp_options/posts/comments/postmeta/users/usermeta — eval payloads, scripts, iframes, hidden admins |
| **wp2shell CVE Chain** | Fingerprint accounts, rogue admins, poisoned oembed_cache, customize_changeset, known shell paths, pre_user_query filter, theme cloaking |
| **CMS Integrity** | Download clean core → diff → delete. WordPress, Joomla, Drupal, PrestaShop, OpenCart, Magento |
| **Network** | Uptime, SSL expiry, DNS baseline, DNSBL (Spamhaus/SpamCop/SORBS), Google Safe Browsing |
| **Mailer** | PHPMailer abuse, raw SMTP, forged headers, known mailer filenames |
| **Hardening** | SSH config, fail2ban, PHP version, world-writable files, /tmp executables, mail queue, WPVulnDB CVEs, open ports baseline, crontab baseline |

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

## Build from source

```bash
cd daemon
go test ./... -timeout 60s
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bpav-daemon .
scp bpav-daemon root@server:/usr/local/bin/
ssh root@server "systemctl restart bpav"
```

---

## Release

```bash
git tag v1.X.Y && git push origin main --tags
# GitHub Actions auto-builds amd64+arm64 → bytespulse-av-releases
```

---

## Scan types

| Type | Modules |
|------|---------|
| `full` | file, integrity, mailer, db, wp2shell, corediff, cms, network, hardening, ports, crontab |
| `file` | file, mailer, integrity |
| `db` | db, wp2shell |
| `network` | network |
| `malware` | file, mailer, db, wp2shell |
| `corediff` | corediff, cms, wp2shell |
| `hardening` | hardening, ports, crontab |

---

## REST API

| Method | Path | Auth |
|--------|------|------|
| GET | /api/v1/health | public |
| GET/POST | /api/v1/settings | admin |
| GET/POST/DELETE | /api/v1/apikeys | admin |
| GET | /api/v1/users | admin |
| POST | /api/v1/scan/{user} | user/admin |
| GET | /api/v1/scan/{user}/jobs | user/admin |
| GET | /api/v1/scan/{user}/history | user/admin |
| GET | /api/v1/scan/job/{id}/status | user/admin |
| GET | /api/v1/scan/job/{id}/results | user/admin |
| GET | /api/v1/scan/job/{id}/stream | user/admin (SSE) |
| GET | /api/v1/reports/summary | admin |

---

## Bilingual (EN/EL)

- Translations: `/etc/bpav/i18n/{en,el}.json` — update-proof (outside plugin dir)
- Per-user language: `/home/USER/.bpav/prefs.json`
- Admin sets default. User can override from panel.
- Emails sent in user's preferred language.

---

## Configuration `/etc/bpav/config.json`

```json
{
  "enabled": true,
  "schedule_day": "friday",
  "schedule_hour": 6,
  "google_safe_browsing_key": "",
  "wpvulndb_token": "",
  "max_workers": 2,
  "since_date": "2026-07-15",
  "default_language": "en"
}
```

---

## Test results

```
ok  github.com/bytespulse/bpav/queue      7 PASS
ok  github.com/bytespulse/bpav/scanner   27 PASS
ok  github.com/bytespulse/bpav/scheduler  6 PASS
ok  github.com/bytespulse/bpav/storage    5 PASS
Total: 44/44 PASS — go vet PASS — shellcheck PASS
```
