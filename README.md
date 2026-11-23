# Open WebUI on Railway

Run [Open WebUI](https://github.com/open-webui/open-webui), the self-hosted AI chat app, on Railway. A ChatGPT-style alternative to ChatGPT, Claude.ai and Gemini that you control: chat with OpenAI, Claude through OpenRouter, Groq or any OpenAI-compatible API, upload documents, and share the instance with your team.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/open-webui?utm_medium=integration&utm_source=template&utm_campaign=open-webui)

## What you get

- The official Open WebUI image, pinned to a tested stable release.
- One service with a volume. Chats, users, uploads and the document index live in SQLite on the volume, so redeploys keep them.
- An admin account created on the first boot from a generated password. Signup is closed, so a stranger can't claim the instance by opening it first.
- The bundled embedding model for document search, used from the image instead of downloaded again on every boot.
- Daily checks for new Open WebUI releases. Each one is smoke-tested before it reaches you.

## After deploying

1. Open the Open WebUI service's public URL. The first boot takes a minute or two.
2. Log in with `WEBUI_ADMIN_EMAIL` and `WEBUI_ADMIN_PASSWORD` from the service's **Variables** tab. The password was generated for you; the email is `admin@localhost` unless you changed it.
3. Connect a model under **Admin Panel → Settings → Connections**: add your OpenAI key, or click **+** to add another OpenAI-compatible API, such as `https://openrouter.ai/api/v1` or `https://api.groq.com/openai/v1`, with its key. If you set `OPENAI_API_KEY` before the first boot, OpenAI is already connected.
4. Start a chat.

Open WebUI does not run models itself here. You need an API key from a model provider; OpenRouter, Groq and Google Gemini have free tiers.

To add people, use **Admin Panel → Users**, or turn signup back on under **Admin Panel → Settings → General**. New signups wait as "pending" until you approve them.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `WEBUI_ADMIN_EMAIL` | `admin@localhost` | Login email for the admin, created on the first boot. Change it later in **Admin Panel → Users** |
| `WEBUI_ADMIN_PASSWORD` | generated | Admin password. Only read on the first boot; change it later under **Settings → Account** |
| `WEBUI_SECRET_KEY` | generated | Signs logins and encrypts saved API keys. Changing it signs everyone out |
| `WEBUI_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL, used in links and for sign-in providers. Update it if you add your own domain |
| `OPENAI_API_KEY` | empty | Optional. Connects OpenAI on the first boot |

Most Open WebUI settings live in its database and are changed in the Admin Panel. Its [environment variables](https://docs.openwebui.com/getting-started/env-configuration) only set the starting values on the first boot. To make variables win over the database every time, set `ENABLE_PERSISTENT_CONFIG=false`.

The template sets these in the Dockerfile: `ENABLE_SIGNUP=false`, `ENABLE_OLLAMA_API=false` (there is no Ollama in this template; turn it on in **Connections** if you run one), `RAG_EMBEDDING_MODEL_AUTO_UPDATE=false`, and the telemetry opt-outs. Public networking should point at port `8080`.

## Storage

The volume is mounted at `/data`. It holds the SQLite database (`webui.db`), uploaded files, the vector index for document search and Open WebUI's caches. Keep it.

For many concurrent users, Open WebUI can use Postgres instead of SQLite: add a Postgres service and set `DATABASE_URL` to `${{Postgres.DATABASE_URL}}` before the first boot. Existing SQLite data does not move over by itself.

## Memory

Open WebUI uses about 700 MB of memory at rest. Much of it is the local embedding model that indexes your documents.

## Updates

A GitHub Action checks Open WebUI's releases once a day. When there is a new one, it builds the template on it and runs the smoke test (`scripts/smoke-test.sh`). Only releases that pass are merged. Failures open an issue instead.

When a bump lands, Railway shows an **update available** notice in your project. Updates are opt-in: apply them when it suits you. Your volume is kept. Open WebUI migrates its database on start.

## Local testing

`scripts/smoke-test.sh` builds the image and starts it from `docker-compose.yml` next to a stand-in for the OpenAI API (`scripts/fake-openai.py`). It checks that the server runs as an unprivileged user with its database on the volume, that the API needs a login, that signup is closed, that the generated admin login works, that a chat gets an answer from the connected model, and that chats and logins survive a restart.

## License

The files in this repository are MIT licensed. Open WebUI is released under the [Open WebUI License](https://github.com/open-webui/open-webui/blob/main/LICENSE), a BSD-3 license with a branding clause: past 50 users in 30 days, you may not remove or change the Open WebUI name and logo without the maintainers' permission. This template runs the image unmodified.
