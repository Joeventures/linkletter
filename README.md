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

### Email templates

Each group has an email template, edited with Action Text's rich-text editor (Trix) at **Group → Email template**. Until you customize it, members get a built-in default email.

Every member must receive their **own** tracked link, so you don't paste a URL into the template. You add a placeholder, and Linkletter swaps in each person's link when it sends. There are three ways to add the link, and the editor has a button and on-screen instructions for each:

| How | What the member sees |
|---|---|
| **Insert link button** (adds `{{link}}`) | An "Open link" button |
| **Link selected text** (highlight words, then click) | Your own words, linked |
| **Insert web address** (adds `{{link_url}}`) | The full personal URL |

Other placeholders: `{{first_name}}`, `{{name}}`, `{{title}}` (the link's title, or "a link"), `{{group}}`. Spaces inside the braces are allowed, and unknown placeholders are left as typed.

- **Subject:** optional. It defaults to the link's title and can use the same placeholders except the link ones.
- **The link is required:** a template without the personal link can't be saved. This stops untracked emails from going out.
- **Plain-text version:** generated automatically. Linked text becomes `words (URL)` there.
- **Preview** shows the subject, HTML and plain-text versions with sample details. **Reset to the default email** discards the template.
- **No images or attachments:** they're disabled in the editor, because emails can't carry Active Storage files.

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
- Per-group email templates built with Action Text, with placeholders, link-insertion buttons, preview, and reset to default (see [Email templates](#email-templates))
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
| **Template injection** | Templates are sanitized by Action Text before placeholders are filled in, and every substituted value (member name, title, group name) is HTML-escaped. `javascript:` links, scripts and event handlers are stripped. |
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
cp .env.example .env                          # optional: local environment variables
bin/setup --skip-server                       # bundle, yarn install, create and migrate the database
bin/rails users:create EMAIL=you@example.com  # prompts for a password (12+ characters)
bin/dev                                       # Rails server + CSS watcher
```

Open http://localhost:3000 and sign in. Emails sent in development appear at http://localhost:3000/letter_opener.

In development:

- **Environment variables** are loaded from `.env` if it exists, using the [dotenv](https://github.com/bkeepers/dotenv) gem (development only). Copy `.env.example`, which lists every variable the app reads. Variables already set in your shell win. `.env` is gitignored; `.env.example` is committed. Nothing in development requires a variable.
- **Email is caught by [letter_opener_web](https://github.com/fgrehm/letter_opener_web)** and never sent. Browse it at http://localhost:3000/letter_opener, where you can open each email, switch between the HTML and plain-text versions, and click the personal links (which hit your local app, so clicks are tracked).
- It's a development-only gem in the `Gemfile`, so there's nothing extra to install or run. Caught emails are saved in `tmp/letter_opener/` and can be cleared from the inbox page.
- The `/letter_opener` route is only mounted in development. It isn't installed or routed in test or production.
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
| `SECRET_KEY_BASE` | secret env var (`.kamal/secrets`) | **Required.** Signs sessions and cookies. Generate once with `bin/rails secret` and keep it stable; changing it signs everyone out. |
| `SMTP_ADDRESS`, `SMTP_PORT` | env var (set in `config/deploy.yml`) | Your email provider's SMTP server. SMTP delivery is enabled when `SMTP_ADDRESS` is set. `SMTP_AUTHENTICATION` defaults to `plain`. |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | secret env vars (`.kamal/secrets`) | Your email provider's SMTP login. |
| Database | `config/database.yml` / `DATABASE_URL` | PostgreSQL. Production also uses the Solid Cache, Solid Queue and Solid Cable databases. |
| Background jobs | `SOLID_QUEUE_IN_PUMA=true` or a separate `bin/jobs` process | Emails are delivered by Solid Queue in production. |
| SSL | `config/deploy.yml` → `proxy` | `assume_ssl` and `force_ssl` are on in `production.rb`. kamal-proxy terminates SSL with an automatic Let's Encrypt certificate for `proxy.host`. Set it to your real domain and point DNS at the server before deploying. `/up` is exempt from the HTTPS redirect for health checks. |
| Hosts | `config.hosts` in `production.rb` | Recommended: restrict to your domain. |

### Secrets and environment variables

This project does **not** use Rails encrypted credentials (`config/credentials.yml.enc`); all configuration and secrets come from environment variables.

- **Development:** `.env` (see above).
- **Production:** Kamal injects variables into the container. Plain values go under `env.clear` in `config/deploy.yml`. Secrets are listed under `env.secret` and their values are read by `.kamal/secrets` from your shell when you run `bin/kamal`, so export `SECRET_KEY_BASE`, `SMTP_USERNAME` and `SMTP_PASSWORD` first (or change `.kamal/secrets` to fetch them from a password manager).
- A `.kamal/hooks/pre-deploy` hook stops any deploy, redeploy or rollback if one of those secrets is blank, so a forgotten `export` can't ship an empty `SECRET_KEY_BASE` or SMTP password.

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
| `app/models/email_template.rb` | Renders a group's template (or the default) for one member: placeholders, HTML and plain text |
| `app/controllers/email_templates_controller.rb`, `app/views/email_templates/` | Template editor, preview, reset |
| `app/javascript/controllers/email_template_controller.js` | Editor buttons: insert placeholders, link selected text, block attachments |
| `lib/tasks/users.rake` | `users:create` task |

### Routes

| Route | Description |
|---|---|
| `GET /l/:token` | Public tracked redirect |
| `/groups` (and nested `/groups/:id/members`, `/groups/:id/links`) | Management UI (sign-in required) |
| `POST /groups/:group_id/members/import` | Bulk member import |
| `POST /groups/:group_id/links/:id/deliver` | Email members who haven't received the link yet |
| `GET/PATCH/DELETE /groups/:group_id/email_template` (+ `/edit`) | Preview, save, and reset the group's email template |
| `/session`, `/passwords` | Sign in/out and password reset |
| `GET /up` | Health check |

---

## Tests and checks

The test suite uses Minitest:

```sh
bin/rails test                               # everything
bin/rails test test/models                   # one directory
bin/rails test test/models/link_test.rb:12   # one test, by line number
```

| Area | Covered |
|---|---|
| Models (`test/models`) | URL validation (accepts http/https, rejects `javascript:`, `data:`, relative and malformed URLs), email normalization and per-group uniqueness, token format and uniqueness, members must belong to the link's group, `deliver_to_members` emails each member once, click recording (browser parsing, bot flag, totals, first/last click times, oversized and multibyte headers) |
| Redirects (`test/controllers/redirects_controller_test.rb`) | Redirects without sign-in, records the click, privacy headers, old browsers still redirected, 404 for unknown, malformed or wrong-case tokens, redirects even if tracking fails |
| Management (`test/controllers`) | Sign-in required, sign in/out, create/update/delete groups, members and links, bulk import formats, "send now" vs. save only, resend to new members, deleting a link disables its personal links, and **every action returns 404 for another account's records** |
| Email templates (`test/models/email_template_test.rb`, `test/controllers/email_templates_controller_test.rb`) | Default and custom rendering, every placeholder, linked text, HTML escaping, sanitization, plain-text output, link required, preview/reset, cross-account 404s |
| Mailer (`test/mailers`) | Each email goes to the right person, contains their personal URL (never the raw destination), and has the right subject |

Rate limiting isn't covered, because the test environment uses a null cache store.

Linters and security scanners:

```sh
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/ci            # setup, lint, security scans and tests
```

GitHub Actions runs the scans, lint and the test suite (against a Postgres service) on every push to `main` and on pull requests.

---

## License

Released under the [MIT License](LICENSE).
