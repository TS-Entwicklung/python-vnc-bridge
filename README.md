# Python VNC Bridge

Docker container to run Python CLI applications (games, scripts) with VNC access via web browser. Optimized for ARM64 devices like BananaPi M5.

## Features

- 🎮 Run any Python CLI application with `.venv` support
- 🌐 Access via browser using noVNC (no VNC client needed)
- 🎨 Full terminal color support (256 colors)
- 🔊 Optional audio support via PulseAudio
- 🔒 Password-protected VNC access
- ⚡ Optimized for ARM64 (BananaPi M5)
- 📦 Easy deployment via Portainer

## Requirements

- Docker & Docker Compose
- Python project with:
  - `__main__.py` (entry point)
  - `.venv/` (virtual environment)
  - Optional: `.env` (project-specific config)

## Quick Start

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd python-vnc-bridge
```

### 2. Edit docker-compose.yml

Edit environment variables and volume mount:

```yaml
environment:
  - VNC_PASSWORD=your_secure_password  # Optional: Leave empty for no password
  - NOVNC_PORT=6080
  - DISPLAY_WIDTH=800
  # ... other settings

volumes:
  - /path/to/your/python/game:/app  # <-- Edit this path
```

### 3. Start Container

```bash
docker-compose up -d
```

### 4. Access via Browser

Open: `http://localhost:6080`

Enter your VNC password from docker-compose environment variables.

## Configuration

### Environment Variables

Set these in `docker-compose.yml` or Portainer Stack environment section:

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | *(empty)* | VNC access password (optional, leave empty for no authentication) |
| `VNC_PORT` | 5900 | VNC server port |
| `NOVNC_PORT` | 6080 | noVNC web interface port |
| `DISPLAY_WIDTH` | 800 | Display width in pixels |
| `DISPLAY_HEIGHT` | 600 | Display height in pixels |
| `VNC_FPS` | 15 | Frame rate (lower = better performance) |
| `ENABLE_AUDIO` | false | Enable audio support (impacts performance) |
| `VNC_COLOR_DEPTH` | 16 | Color depth (16 or 24 bit) |

### Performance Tuning for BananaPi M5

For better performance on ARM devices:
- Keep `VNC_FPS=15` or lower
- Use `VNC_COLOR_DEPTH=16`
- Disable audio if not needed: `ENABLE_AUDIO=false`
- Reduce resolution: `DISPLAY_WIDTH=640 DISPLAY_HEIGHT=480`

## Portainer Deployment

### Using Portainer Stacks

1. In Portainer, go to **Stacks** → **Add Stack**
2. Choose **Repository** as build method
3. Enter your Git repository URL
4. Set **Compose path**: `docker-compose.yml`
5. In the **Environment variables** section, add (all optional):
   - `VNC_PASSWORD` (leave empty for no password)
   - `NOVNC_PORT` (default: 6080)
   - Other settings as needed
6. **Important**: Edit the volume path in the stack editor:
   ```yaml
   volumes:
     - /your/actual/path:/app
   ```
7. Deploy!

### Volume Mount Path

The container expects your Python project at `/app`. You must configure the host path in `docker-compose.yml`:

```yaml
volumes:
  - /home/user/my-game:/app  # Host path : Container path
```

The `/app` directory must contain:
```
/app/
├── __main__.py    # Required: Entry point
├── .venv/         # Required: Python virtual environment
└── .env           # Optional: Project-specific config
```

## Project Structure

```
python-vnc-bridge/
├── Dockerfile                  # Container definition
├── docker-compose.yml          # Service configuration
├── entrypoint.sh              # Startup script
├── .env.example               # Environment reference (optional)
├── .gitignore                # Git ignore rules
├── README.md                 # Setup documentation
└── WEBSITE_INTEGRATION.md    # Website integration guide
```

## Troubleshooting

### No password prompt / Can't connect
VNC password is optional. Leave `VNC_PASSWORD` empty for open access, or set it in docker-compose.yml environment section.

### "/app/__main__.py not found"
Check volume mount path in `docker-compose.yml` points to your Python project.

### "/app/.venv directory not found"
Ensure your Python project has a virtual environment:
```bash
cd /path/to/your/game
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt  # if needed
```

### Container starts but Python app doesn't run
Check logs:
```bash
docker-compose logs -f
```

Verify `__main__.py` is executable:
```bash
python __main__.py  # Test locally first
```

### Performance issues on BananaPi
- Lower FPS: `VNC_FPS=10`
- Reduce resolution: `DISPLAY_WIDTH=640 DISPLAY_HEIGHT=480`
- Disable audio: `ENABLE_AUDIO=false`
- Use 16-bit color: `VNC_COLOR_DEPTH=16`

### Can't connect to noVNC
- Check ports are not blocked: `http://<bananapi-ip>:6080`
- Verify container is running: `docker-compose ps`
- Check firewall settings on BananaPi

## Technical Details

### Stack
- **Base Image**: Debian Bookworm Slim
- **VNC Server**: TigerVNC
- **Web Interface**: noVNC + websockify
- **Display**: Xvfb (virtual framebuffer)
- **Terminal**: xterm with 256-color support
- **Audio**: PulseAudio (optional)

### Architecture
- ARM64/aarch64 native (BananaPi M5)
- Also works on AMD64/x86_64

## Security Notes

- **Warning**: VNC password is optional but recommended for production
- Set a strong `VNC_PASSWORD` when exposing to network
- Don't expose VNC ports directly to the internet without authentication
- Use reverse proxy (nginx, Traefik) with HTTPS for production
- Consider adding HTTP basic auth for noVNC endpoint

## License

MIT

## Contributing

Issues and pull requests welcome!
