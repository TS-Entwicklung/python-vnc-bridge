# Multi-stage build optimized for ARM64 (BananaPi M5)
FROM debian:bookworm-slim

# Set environment defaults
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    DISPLAY_WIDTH=800 \
    DISPLAY_HEIGHT=600 \
    VNC_FPS=15 \
    ENABLE_AUDIO=false

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # VNC and Display
    tigervnc-standalone-server \
    tigervnc-common \
    xvfb \
    xterm \
    x11-utils \
    # noVNC for web access
    novnc \
    websockify \
    # Audio (optional)
    pulseaudio \
    alsa-utils \
    # Python runtime dependencies
    python3 \
    python3-venv \
    python3-pip \
    # Git for repository cloning
    git \
    # Utilities
    procps \
    net-tools \
    curl \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

# Setup VNC directories
RUN mkdir -p /root/.vnc /root/.config/pulse

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE ${VNC_PORT} ${NOVNC_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${NOVNC_PORT}/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
