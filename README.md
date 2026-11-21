# Linkletter

Linkletter sends a group of people a link where **each person gets their own unique, trackable URL**. When someone clicks their link, Linkletter records the click (who, when, IP address, browser, device and more) and then redirects them to the real destination.

**Example:** you want to share a YouTube live stream with a group. You create the group, add the people, then add the stream URL. Every member gets an email with their own personal link, so you can see exactly who clicked and when.

---

## How it works

```
Group ──< Member
  │          │
  └──< Link ─┴──< PersonalLink ──< Click
```

| Model | What it is |
|---|---|
| **User** | An account that manages groups. Each user only ever sees their own data. |
| **Group** | A named list of people, e.g. "Sunday livestream viewers". |
| **Member** | A person in a group (name and email). An email can appear only once per group. |
| **Link** | A destination URL (e.g. a YouTube live video) added to a group, with an optional title. |
| **PersonalLink** | One per member per link. Holds the secret token that makes up the member's unique URL (`/l/<token>`), plus send status and click totals. |
| **Click** | One row per visit to a personal link: IP address, user agent, parsed browser/version, platform, device type, referrer, `Accept-Language`, and a bot flag. |

### The flow

1. **Create a group** and **add members**, one at a time or by pasting a list.
2. **Add a link** to the group. With "Email each member their personal link now" checked (the default), Linkletter:
   - creates a `PersonalLink` with a random token for every member, and
   - queues one email per member (`LinkMailer#personal_link`) containing their unique URL, e.g. `https://your-domain/l/rnQUXKFgK7yVV1xj7upJkGMiRgLaApJo`.
3. **A member clicks their link.** `RedirectsController` looks up the token, records a `Click`, updates the personal link's click totals and first/last click times, then sends a `302` redirect to the destination.
4. **View the results** on the link's page: who it was sent to, how many times each person clicked, first and last click, and the full click log.

### Members added later

If you add members after a link was sent, the link's page lists them as "Not sent yet" and shows an **Email N members who haven't received it** button. Sending is idempotent: members who already have a personal link for that link are never emailed twice.

---

## Features

- Account login with password reset (Rails 8 built-in authentication)
- Groups with optional descriptions
- Members: add individually, edit, remove, or bulk import by pasting
  - Accepted formats, one per line: `Jane Doe, jane@example.com`, `Jane Doe <jane@example.com>`, or just `jane@example.com`
  - Invalid lines and duplicates are skipped and reported
- Links: any `http://` or `https://` URL with an optional title, which becomes the email subject
- Personal emails (HTML and plain text), sent in the background via Active Job
- Click tracking per person:
  - timestamp
  - IP address
  - browser name and version, OS/platform, device type (desktop, mobile, tablet, console, TV)
  - full user agent string (shown on hover in the click log)
  - referrer and `Accept-Language`
  - bot / link-scanner detection
- Per-link dashboard: recipients table (sent time, click count, first/last click, copyable personal URL) and a log of the 200 most recent clicks
- Deleting a link or member disables the personal links already sent and removes their click history, after a confirmation prompt

---

## Security

| Concern | How it's handled |
|---|---|
| **Guessing someone's link** | Tokens are 32 random base58 characters (about 187 bits) from `has_secure_token`, so they can't be guessed or enumerated. Malformed tokens are rejected with a 404 before any database lookup. |
| **Brute forcing** | The redirect endpoint is rate-limited to 30 requests per minute per IP. Sign-in is limited to 10 attempts per 3 minutes. |
| **Malicious destinations** | Link URLs must be absolute `http`/`https` URLs with a host, so a stored link can't be a `javascript:`, `data:` or relative redirect. |
| **Seeing other accounts' data** | Every management controller loads records through `Current.user.groups` (see `GroupScoped`). Requesting another account's group, member or link returns a 404. |
| **Open sign-up** | There is no registration page. Accounts are created from the command line (see below). |
| **Token leaking to the destination** | Redirects send `Referrer-Policy: no-referrer`, so the destination site (e.g. YouTube) never sees the personal URL. |
| **Caching or indexing** | Redirects send `Cache-Control: no-store` and `X-Robots-Tag: noindex, nofollow`. |
| **Weak passwords** | Minimum 12 characters. Passwords are stored with bcrypt. |
| **CSRF / sessions** | Standard Rails CSRF protection. Session cookies are signed, `httponly` and `SameSite=Lax`. Production forces HTTPS: secure-only cookies, HSTS, and HTTP→HTTPS redirects. |

Design notes:

- `RedirectsController` inherits from `ActionController::Base` instead of `ApplicationController`. It needs no login, and it must not apply `allow_browser versions: :modern`, which would block older browsers and email clients instead of redirecting them.
- If recording a click ever fails, the error is logged and the visitor is still redirected.

### About bot clicks

Many corporate email systems (e.g. Microsoft Defender Safe Links, Mimecast) automatically "click" links in incoming mail to scan them. Clicks whose user agent identifies a bot are flagged with a **bot** badge, but some scanners pretend to be normal browsers. A click within seconds of the email being sent, especially from a data-center IP, is often a scanner rather than the person.

---

## Setup (development)

### Requirements

- Ruby **4.0.10** (see `.ruby-version`)
- Node **25.2.1** (see `.node-version`) and Yarn, used to build the Bootstrap CSS
- PostgreSQL

### Install and run

```sh
bin/setup --skip-server                       # bundle, yarn install, create and migrate the database
bin/rails users:create EMAIL=you@example.com  # prompts for a password (12+ characters)
bin/dev                                       # Rails server + CSS watcher
```

Open http://localhost:3000 and sign in.

In development:

- Emails are not actually sent. Each email, including its personal link, is written to `log/development.log`.
- Jobs run in-process with the `:async` adapter.

> **Postgres.app on macOS:** Postgres.app asks for permission the first time a new process connects. Avoid `rails server -d` (daemon mode). The detached process can't show the prompt and requests will hang. Run the server in the foreground with `bin/dev`.

### Creating accounts

```sh
bin/rails users:create EMAIL=someone@example.com
```

---

## Configuration (production)

| Setting | Where | Notes |
|---|---|---|
| `MAIL_FROM` | env var | Sender address, e.g. `Linkletter <links@yourdomain.com>`. Defaults to `no-reply@example.com`. |
| `APP_HOST` | env var (set in `config/deploy.yml`) | **Required.** The domain used to build the `https://` personal URLs in emails. Use a short domain, since it appears in every link. Keep it the same as `proxy.host`. |
| SMTP | `config/environments/production.rb` → `config.action_mailer.smtp_settings` | Credentials for your email provider (Postmark, SES, SendGrid, etc.), ideally stored in `bin/rails credentials:edit`. |
| `RAILS_MASTER_KEY` | env var | Decrypts `config/credentials.yml.enc`. |
| Database | `config/database.yml` / `DATABASE_URL` | PostgreSQL. Production also uses the Solid Cache, Solid Queue and Solid Cable databases. |
| Background jobs | `SOLID_QUEUE_IN_PUMA=true` or a separate `bin/jobs` process | Emails are delivered by Solid Queue in production. |
| SSL | `config/deploy.yml` → `proxy` | `assume_ssl` and `force_ssl` are on in `production.rb`. kamal-proxy terminates SSL with an automatic Let's Encrypt certificate for `proxy.host`. Set it to your real domain and point DNS at the server before deploying. `/up` is exempt from the HTTPS redirect for health checks. |
| Hosts | `config.hosts` in `production.rb` | Recommended: restrict to your domain. |

### HTTPS and other hosting setups

The app expects an SSL-terminating proxy in front of it, because `assume_ssl` treats every request as HTTPS. kamal-proxy does this by default.

- **Cloudflare:** set SSL/TLS mode to **Full**.
- **Multiple web servers:** kamal-proxy SSL only works with a single web server. Terminate SSL at your load balancer instead and remove `ssl: true` from `proxy`.
- **No proxy:** if you serve the app without one, set `assume_ssl` to `false`.

HSTS is on. It tells browsers to use only HTTPS for your domain and its subdomains for two years, so deploy to a domain you intend to keep on HTTPS.

### Behind a proxy or load balancer

Click IP addresses come from `request.remote_ip`. If you deploy behind a proxy or CDN other than Kamal/Thruster (e.g. Cloudflare), configure `config.action_dispatch.trusted_proxies`. Otherwise every click may record the proxy's IP instead of the visitor's.

### Deploying

The app includes the standard Rails 8 Kamal setup (`config/deploy.yml`, `Dockerfile`). Before the first deploy, replace the placeholders in `config/deploy.yml`:

- `servers.web`
- `registry`
- `proxy.host` and `APP_HOST` (both are `links.example.com` now)

Then run:

```sh
bin/kamal setup    # first deploy
bin/kamal deploy   # later deploys
```

---

## Code map

| Path | Purpose |
|---|---|
| `app/controllers/redirects_controller.rb` | Public `/l/:token` endpoint: validates the token, records the click, redirects |
| `app/models/personal_link.rb` | Token generation (`has_secure_token`) and `record_click!` (user agent parsing via the `browser` gem) |
| `app/models/link.rb` | URL validation and `deliver_to_members` (create personal links and queue emails) |
| `app/controllers/concerns/group_scoped.rb` | Scopes nested resources to the signed-in user's groups |
| `app/controllers/{groups,members,links}_controller.rb` | Management UI |
| `app/mailers/link_mailer.rb`, `app/views/link_mailer/` | The personal-link email |
| `lib/tasks/users.rake` | `users:create` task |

### Routes

| Route | Description |
|---|---|
| `GET /l/:token` | Public tracked redirect |
| `/groups` (and nested `/groups/:id/members`, `/groups/:id/links`) | Management UI (sign-in required) |
| `POST /groups/:group_id/members/import` | Bulk member import |
| `POST /groups/:group_id/links/:id/deliver` | Email members who haven't received the link yet |
| `/session`, `/passwords` | Sign in/out and password reset |
| `GET /up` | Health check |

---

## Checks

The app was generated without a test framework. Run the linters and security scanners with:

```sh
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/ci            # runs all of the above plus setup
```

---

## License

Released under the [MIT License](LICENSE).
