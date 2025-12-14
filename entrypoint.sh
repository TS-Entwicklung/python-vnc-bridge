#!/bin/bash
set -e

echo "========================================"
echo "Python VNC Bridge Starting..."
echo "========================================"

# Git Clone Feature (optional)
if [ -n "$GIT_REPO" ]; then
    echo "Git repository detected: $GIT_REPO"

    # Check if /app is empty (ignore hidden files for now)
    if [ -d "/app/.git" ] || [ "$(ls -A /app 2>/dev/null | grep -v '^\.' | wc -l)" -gt 0 ]; then
        echo "WARNING: /app is not empty, skipping clone"
    else
        echo "Cloning repository to /app..."

        # Build Git URL with credentials if provided
        if [ -n "$GIT_USERNAME" ] && [ -n "$GIT_TOKEN" ]; then
            # Extract protocol and rest of URL
            GIT_PROTOCOL=$(echo "$GIT_REPO" | grep -o '^[^:]*')
            GIT_REST=$(echo "$GIT_REPO" | sed 's|^[^:]*://||')
            GIT_URL_WITH_AUTH="${GIT_PROTOCOL}://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_REST}"
            echo "Using authenticated Git URL (credentials hidden)"
        else
            GIT_URL_WITH_AUTH="$GIT_REPO"
            echo "Using public Git URL"
        fi

        # Clone with optional branch
        GIT_BRANCH=${GIT_BRANCH:-main}
        echo "Cloning branch: $GIT_BRANCH"

        if git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_URL_WITH_AUTH" /tmp/repo; then
            # Move contents to /app
            mv /tmp/repo/.git /app/
            mv /tmp/repo/* /app/ 2>/dev/null || true
            mv /tmp/repo/.* /app/ 2>/dev/null || true
            rm -rf /tmp/repo
            echo "✅ Repository cloned successfully"
        else
            echo "❌ ERROR: Failed to clone repository"
            echo "Check GIT_REPO, GIT_BRANCH, and credentials"
            exit 1
        fi
    fi
else
    echo "No GIT_REPO specified, expecting mounted volume"
fi

# Check if Python project exists
if [ ! -f "/app/__main__.py" ]; then
    echo "ERROR: /app/__main__.py not found"
    if [ -n "$GIT_REPO" ]; then
        echo "Repository was cloned but does not contain __main__.py"
    else
        echo "Please mount your Python project to /app volume or set GIT_REPO"
    fi
    exit 1
fi

# Check if .venv exists
if [ ! -d "/app/.venv" ]; then
    echo "ERROR: /app/.venv directory not found"
    echo "Please ensure your Python project has a virtual environment"
    echo "You can create one with: python3 -m venv .venv"
    exit 1
fi

# Set VNC password (optional)
mkdir -p /root/.vnc
if [ -n "$VNC_PASSWORD" ]; then
    echo "VNC authentication: enabled"
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    VNC_SECURITY_TYPE="VncAuth"
else
    echo "VNC authentication: disabled (no password)"
    VNC_SECURITY_TYPE="None"
fi

# Set color depth (default to 16 for performance)
VNC_COLOR_DEPTH=${VNC_COLOR_DEPTH:-16}

echo "Starting Xvfb display server..."
Xvfb $DISPLAY -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${VNC_COLOR_DEPTH} -ac &
XVFB_PID=$!
sleep 2

# Start PulseAudio if audio is enabled
if [ "$ENABLE_AUDIO" = "true" ]; then
    echo "Starting PulseAudio..."
    pulseaudio --start --exit-idle-time=-1 &
    sleep 1
fi

echo "Starting TigerVNC server on port $VNC_PORT..."
vncserver $DISPLAY \
    -rfbport $VNC_PORT \
    -geometry ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} \
    -depth $VNC_COLOR_DEPTH \
    -localhost no \
    -SecurityTypes $VNC_SECURITY_TYPE \
    -MaxIdleTime 0 \
    -AlwaysShared \
    -DisconnectClients=0 &
VNC_PID=$!
sleep 2

echo "Starting noVNC web interface on port $NOVNC_PORT..."
websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT &
NOVNC_PID=$!
sleep 2

# Activate Python virtual environment
echo "Activating Python virtual environment..."
cd /app
source .venv/bin/activate

# Get Python version
PYTHON_VERSION=$(python --version 2>&1)
echo "Using: $PYTHON_VERSION"

# Check if .env exists in app directory
if [ -f "/app/.env" ]; then
    echo "Found /app/.env file (loaded by Python script)"
fi

echo "========================================"
echo "VNC Bridge Ready!"
echo "========================================"
echo "Access via browser: http://localhost:$NOVNC_PORT"
if [ -n "$VNC_PASSWORD" ]; then
    echo "VNC Password: ******* (protected)"
else
    echo "VNC Password: none (open access)"
fi
echo "Display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} @ ${VNC_FPS}fps"
echo "Audio: $ENABLE_AUDIO"
echo "========================================"
echo ""
echo "Starting Python application..."
echo ""

# Start Python application in xterm
XTERM_CMD="cd /app && source .venv/bin/activate && python __main__.py; echo ''; echo 'Application exited. Press Ctrl+C to stop container.'; bash"

xterm -maximized \
    -fa 'Monospace' \
    -fs 12 \
    -bg black \
    -fg white \
    +sb \
    -e bash -c "$XTERM_CMD" &
XTERM_PID=$!

# Cleanup function
cleanup() {
    echo ""
    echo "Shutting down..."
    kill $XTERM_PID 2>/dev/null || true
    kill $NOVNC_PID 2>/dev/null || true
    vncserver -kill $DISPLAY 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    if [ "$ENABLE_AUDIO" = "true" ]; then
        pulseaudio --kill 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep container running
wait $XTERM_PID
