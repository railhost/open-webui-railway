# Deploy and Host Open WebUI (Self-Hosted AI Chat, ChatGPT Alternative) on Railway

Open WebUI is a self-hosted AI chat app that looks and works like ChatGPT. Chat with OpenAI, Claude through OpenRouter, Groq, Gemini or any OpenAI-compatible API, upload documents and ask questions about them, and share one instance with your team. Your chats stay on a server you control.

## About Hosting Open WebUI

This template runs the official Open WebUI image in one Railway service with a volume. Chats, users, uploads and the document index live in SQLite on the volume, so redeploys keep them.

Out of the box, the first visitor to a new Open WebUI install becomes its admin. On a public URL a stranger could get there first. This template creates the admin account on the first boot from a generated password and closes signup.

After deploying:

1. Open the service's public URL. The first boot takes a minute or two.
2. Log in with `WEBUI_ADMIN_EMAIL` and `WEBUI_ADMIN_PASSWORD` from the Variables tab.
3. Add a model provider under Admin Panel → Settings → Connections, or set `OPENAI_API_KEY` before the first boot.
4. Start a chat.

A GitHub Action checks for new Open WebUI releases every day and smoke-tests each one before it reaches you. Railway then shows an update notice in your project, and you apply it when it suits you.

## Common Use Cases

- A private ChatGPT alternative for yourself or your team, paid per use instead of per seat
- One chat app for many models: OpenAI, Claude, Gemini, Groq and OpenRouter side by side
- Ask questions about your own PDFs and documents
- Give a team shared prompts, models and chat history with admin-controlled accounts

## Dependencies for Open WebUI Hosting

- An API key from a model provider: OpenAI, OpenRouter, Groq, Google Gemini or any OpenAI-compatible API. OpenRouter, Groq and Gemini have free tiers.
- Optional: Postgres instead of SQLite for many concurrent users

### Deployment Dependencies

- Open WebUI: https://github.com/open-webui/open-webui
- Open WebUI docs: https://docs.openwebui.com
- Environment variables: https://docs.openwebui.com/getting-started/env-configuration
- Template source: https://github.com/railhost/open-webui-railway

### Implementation Details

The volume is mounted at `/data` and holds the SQLite database, uploaded files, the vector index for document search and caches. The template runs no models itself and turns Ollama off; turn it back on under Connections if you run one elsewhere.

Most Open WebUI settings live in its database. Environment variables only set the starting values on the first boot, unless you set `ENABLE_PERSISTENT_CONFIG=false`.

The service uses about 700 MB of memory at rest, mostly for the local embedding model that indexes your documents. Open WebUI's license asks deployments with more than 50 users in 30 days to keep its name and logo.

## Why Deploy Open WebUI on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Open WebUI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
