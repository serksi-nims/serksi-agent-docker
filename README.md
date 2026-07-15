# Serksi Agent — Docker

Run the Serksi agent on your own Linux machine instead of a Serksi hardware appliance.

## Requirements

- **Linux host** (physical or VM) — Ubuntu 22.04+ or Debian 12 recommended
- **Kernel 5.6+** for Remote Access (VPN) support
- The host must be **on the network you want to monitor**
- A Serksi account at [portal.serksi.com](https://portal.serksi.com)

> **Linux only.** The agent shares the host's network to discover devices, which
> Docker Desktop for Mac/Windows cannot do. On those platforms, run it inside a
> Linux VM bridged to the network you want to monitor.

## Install

### Quick install

```bash
curl -sL https://get.serksi.com/install | sudo bash
```

Installs Docker if needed, starts the agent, and prints the URL to register at.

### Manual install

If you'd rather see each step:

```bash
# 1. Install Docker (skip if you have it, with Compose v2)
curl -fsSL https://get.docker.com | sudo sh

# 2. Get the compose file
sudo mkdir -p /opt/serksi-agent && cd /opt/serksi-agent
sudo curl -sLO https://get.serksi.com/docker-compose.yml

# 3. Start the agent
sudo docker compose up -d
```

> **Note:** `apt install docker.io` does **not** include Compose v2. Use
> `get.docker.com` or Docker's official repository.

## Register

1. Find the host's IP:
```bash
   hostname -I | awk '{print $1}'
```

2. Open `https://<that-ip>:5443` in a browser.

3. **You'll see a certificate warning.** This is expected — the agent generates a
   self-signed certificate, because no public authority can issue one for a
   private IP address. Click **Advanced → Proceed**.

4. Sign in with your Serksi account and register the agent to a site.

Scanning starts immediately, and the agent appears in your portal.

## Managing the agent

Run from your install directory (`/opt/serksi-agent` by default):

| Task | Command |
|---|---|
| Logs | `docker compose logs -f` |
| Status | `docker compose ps` |
| Stop | `docker compose down` |
| Start | `docker compose up -d` |
| Restart | `docker compose restart` |
| Update | `docker compose pull && docker compose up -d` |

## Configuration

The agent needs no configuration — it auto-detects your network interface. For
the exceptions, copy `.env.example` to `.env`:

```bash
sudo curl -sLO https://get.serksi.com/.env.example
sudo cp .env.example .env
```

| Variable | Purpose |
|---|---|
| `SERKSI_INTERFACE` | Pin the LAN interface (auto-detected otherwise) |
| `SERKSI_SITE_TOKEN` + `SERKSI_SITE_ID` | Register without the wizard |
| `SERKSI_API_URL` | Point at a self-hosted Serksi server |

After editing `.env`: `docker compose up -d`

## Troubleshooting

**Container keeps restarting — "network interface does not exist"**

Auto-detection failed. List your interfaces:
```bash
ip link
```
Then pin the right one:
```bash
echo "SERKSI_INTERFACE=ens33" | sudo tee .env    # your interface here
sudo docker compose up -d
```

**The wizard won't load**
- Is it running? `docker compose ps`
- Check the logs for the certificate line: `docker compose logs | grep -i cert`
- Is a host firewall blocking port 5443?

**Registered, but few devices found**

Check which interface was picked:
```bash
docker compose logs | grep -i "interface"
```
If it's the wrong one (e.g. a Docker bridge rather than your LAN), pin it with
`SERKSI_INTERFACE`.

**`unknown shorthand flag: 'd'`**

You have Docker Compose v1. Install v2:
```bash
curl -fsSL https://get.docker.com | sudo sh
```

## Uninstall

```bash
cd /opt/serksi-agent
sudo docker compose down -v      # -v also removes registration and certificates
```

Then remove the site from your Serksi portal.

## Support

- Docs: [serksi.com](https://serksi.com)
- Portal: [portal.serksi.com](https://portal.serksi.com)