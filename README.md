# Python VNC Bridge

Docker container to run Python CLI applications (games, scripts) with VNC access via web browser. Optimized for ARM64 devices like BananaPi M5.

## Features

- 🎮 Run any Python CLI application with `.venv` support
- 🖥️ **Lightweight LXDE Desktop Environment** - Full desktop experience optimized for ARM64
- 🌐 Access via browser using noVNC (no VNC client needed)
- 🎨 Full terminal color support (256 colors)
- 🔊 Optional audio support via PulseAudio
- 🔒 Password-protected VNC access (optional)
- 🔄 **Git repository cloning on startup** (alternative to volume mount)
- ⚡ Optimized for ARM64 (BananaPi M5)
- 📦 Easy deployment via Portainer

## Requirements

- Docker & Docker Compose
- Python project with:
  - `__main__.py` (entry point)
  - `requirements.txt` (optional - automatically installs dependencies)
  - Optional: `.env` (project-specific config)

**Two deployment modes:**
1. **Volume Mount**: Mount local Python project directory
2. **Git Clone**: Automatically clone from GitHub/GitLab on container start

**Note**: The `.venv` virtual environment is created automatically on startup if it doesn't exist.

## Quick Start

Choose one of two methods:

### Method 1: Using Volume Mount (Local Development)

1. **Clone this repository:**
```bash
git clone <your-repo-url>
cd python-vnc-bridge
```

2. **Edit docker-compose.yml:**
```yaml
volumes:
  - /path/to/your/python/game:/app  # <-- Point to your Python project

environment:
  - VNC_PASSWORD=your_password  # Optional
  - DEBUG=true  # Enable detailed logging (optional)
```

3. **Start container:**
```bash
docker-compose up -d
```

### Method 2: Using Git Clone (Production/Remote)

1. **Edit docker-compose.yml:**
```yaml
# Comment out or remove volumes section
# volumes:
#   - ./app:/app

environment:
  - VNC_PASSWORD=your_password  # Optional
  - GIT_REPO=https://github.com/username/your-python-game.git
  - GIT_BRANCH=main  # Optional, defaults to main
  # For private repos:
  # - GIT_USERNAME=your-github-username
  # - GIT_TOKEN=ghp_your_personal_access_token
```

2. **Start container:**
```bash
docker-compose up -d
```

The container will automatically clone your repository to `/project` on startup.

**Important**:
- Volume mounts use `/app` directory
- Git clones use `/project` directory

### Access via Browser

Open: `http://localhost:6080`

Enter your VNC password (if configured).

## Configuration

### Environment Variables

Set these in `docker-compose.yml` or Portainer Stack environment section:

#### VNC Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | false | Enable detailed debug logging (true/false) |
| `VNC_PASSWORD` | *(empty)* | VNC access password (optional, leave empty for no authentication) |
| `VNC_PORT` | 5900 | VNC server port |
| `NOVNC_PORT` | 6080 | noVNC web interface port |
| `DISPLAY_WIDTH` | 800 | Display width in pixels |
| `DISPLAY_HEIGHT` | 600 | Display height in pixels |
| `VNC_FPS` | 15 | Frame rate (lower = better performance) |
| `ENABLE_AUDIO` | false | Enable audio support (impacts performance) |
| `VNC_COLOR_DEPTH` | 16 | Color depth (16 or 24 bit) |
| `START_PYTHON_APP` | true | Auto-start Python app in desktop terminal |

#### Git Clone Configuration (Alternative to Volume Mount)

| Variable | Default | Description |
|----------|---------|-------------|
| `GIT_REPO` | *(empty)* | Git repository URL (HTTPS). If set, clones to `/project` on startup |
| `GIT_BRANCH` | `main` | Branch to clone (optional) |
| `GIT_USERNAME` | *(empty)* | GitHub username for private repositories (optional) |
| `GIT_TOKEN` | *(empty)* | Personal Access Token for private repositories (optional) |

**Note:** If `GIT_REPO` is set, the container will clone the repository on startup instead of using volume mount.

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
     - /your/actual/path:/app  # For volume mount
   ```
7. Deploy!

### Volume Mount Path

**Two directories are used depending on deployment mode:**

#### Volume Mount Mode (no GIT_REPO set)
The container expects your Python project at `/app`:

```yaml
volumes:
  - /home/user/my-game:/app  # Host path : Container path
```

#### Git Clone Mode (GIT_REPO is set)
The container clones to `/project` automatically. No volume mount needed.

**Required project structure:**
```
/app/ (or /project/)
├── __main__.py       # Required: Entry point
├── requirements.txt  # Optional: Auto-installed on startup
└── .env              # Optional: Project-specific config
```

**Note**: The `.venv` directory is created automatically on first startup.

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

### "__main__.py not found"
- For **volume mount**: Check volume mount path in `docker-compose.yml` points to your Python project at `/app`
- For **git clone**: Ensure your repository contains `__main__.py` in the root directory

Enable debug mode to see detailed information:
```yaml
environment:
  - DEBUG=true
```

### Virtual environment issues
The `.venv` is created automatically on container startup. If you have `requirements.txt`, dependencies will be installed automatically.

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
- **Desktop Environment**: LXDE (Lightweight X11 Desktop Environment)
- **VNC Server**: TigerVNC
- **Web Interface**: noVNC + websockify
- **Display**: Xvfb (virtual framebuffer)
- **Terminal**: lxterminal with 256-color support
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
