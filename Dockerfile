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
    ENABLE_AUDIO=false \
    START_PYTHON_APP=true

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # VNC and Display
    tigervnc-standalone-server \
    tigervnc-common \
    xvfb \
    xterm \
    x11-utils \
    # Lightweight Desktop Environment (LXDE) for BananaPi M5
    lxde-core \
    lxde-common \
    lxterminal \
    lxappearance \
    lxpanel \
    pcmanfm \
    openbox \
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
    # Additional tools for desktop
    dbus-x11 \
    at-spi2-core \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /project
WORKDIR /app

# Setup VNC directories and desktop environment
RUN mkdir -p /root/.vnc /root/.config/pulse /root/.config/lxpanel /root/.config/pcmanfm /root/Desktop

# Create desktop autostart directory
RUN mkdir -p /root/.config/autostart

# Set up LXDE default configuration
RUN echo "#!/bin/sh" > /root/.xinitrc && \
    echo "exec startlxde" >> /root/.xinitrc && \
    chmod +x /root/.xinitrc

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports (use default values for EXPOSE)
EXPOSE 5900 6080

# Health check (use default port 6080)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
