#!/bin/bash
# Don't use set -e here, we handle errors manually
# set -e

# Enable debug mode if DEBUG=true
if [ "$DEBUG" = "true" ]; then
    set -x
    echo "🐛 DEBUG MODE ENABLED"
fi

# Set default environment variables if not set
export DISPLAY=${DISPLAY:-:1}
export VNC_PORT=${VNC_PORT:-5900}
export NOVNC_PORT=${NOVNC_PORT:-6080}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-800}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-600}
export VNC_FPS=${VNC_FPS:-15}
export ENABLE_AUDIO=${ENABLE_AUDIO:-false}
export VNC_COLOR_DEPTH=${VNC_COLOR_DEPTH:-16}

echo "========================================"
echo "Python VNC Bridge Starting..."
echo "========================================"
echo "🔍 DEBUG: Timestamp: $(date)"
echo "🔍 DEBUG: Host: $(hostname)"
echo "🔍 DEBUG: User: $(whoami)"

# Determine project directory
PROJECT_DIR=""

# Git Clone Feature (optional)
if [ -n "$GIT_REPO" ]; then
    echo "📦 Git repository detected: $GIT_REPO"
    echo "🔍 DEBUG: Using /project directory for Git clone"
    PROJECT_DIR="/project"

    # Clean /project directory before cloning
    echo "🔍 DEBUG: Preparing /project directory for cloning..."
    if [ -d "/project" ]; then
        echo "🧹 Cleaning /project directory..."
        rm -rf /project/*
        rm -rf /project/.[!.]*
        echo "✅ /project directory cleaned"
    else
        echo "📁 Creating /project directory..."
        mkdir -p /project
    fi

    echo "📥 Cloning repository to /project..."

    # Build Git URL with credentials if provided
    if [ -n "$GIT_USERNAME" ] && [ -n "$GIT_TOKEN" ]; then
        # Extract protocol and rest of URL
        GIT_PROTOCOL=$(echo "$GIT_REPO" | grep -o '^[^:]*')
        GIT_REST=$(echo "$GIT_REPO" | sed 's|^[^:]*://||')
        GIT_URL_WITH_AUTH="${GIT_PROTOCOL}://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_REST}"
        echo "🔐 Using authenticated Git URL (credentials hidden)"
    else
        GIT_URL_WITH_AUTH="$GIT_REPO"
        echo "🌐 Using public Git URL"
    fi

    # Clone with optional branch
    GIT_BRANCH=${GIT_BRANCH:-main}
    echo "🌿 Cloning branch: $GIT_BRANCH"

    if git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_URL_WITH_AUTH" /tmp/repo 2>&1; then
        echo "🔍 DEBUG: Git clone successful, moving files..."
        # Move contents to /project (careful with hidden files)
        if [ -d "/tmp/repo/.git" ]; then
            mv /tmp/repo/.git /project/ 2>/dev/null || true
        fi
        # Move all visible files
        if [ "$(ls -A /tmp/repo 2>/dev/null)" ]; then
            mv /tmp/repo/* /project/ 2>/dev/null || true
        fi
        # Move hidden files (but not . and ..)
        for file in /tmp/repo/.*; do
            if [ -f "$file" ] || [ -d "$file" ]; then
                filename=$(basename "$file")
                if [ "$filename" != "." ] && [ "$filename" != ".." ]; then
                    mv "$file" /project/ 2>/dev/null || true
                fi
            fi
        done
        rm -rf /tmp/repo
        echo "✅ Repository cloned successfully"
        echo "🔍 DEBUG: Contents of /project after clone:"
        ls -la /project/ || true
    else
        echo "❌ ERROR: Failed to clone repository"
        echo "🔍 DEBUG: Git clone failed"
        echo "Check GIT_REPO, GIT_BRANCH, and credentials"
        exit 1
    fi
else
    echo "📂 No GIT_REPO specified, using volume mount at /app"
    echo "🔍 DEBUG: Using /app directory for volume mount"
    PROJECT_DIR="/app"

    echo "🔍 DEBUG: Checking /app directory..."
    if [ -d "/app" ]; then
        echo "✅ /app directory exists"
        echo "🔍 DEBUG: Contents of /app:"
        ls -la /app/ || true
    else
        echo "❌ ERROR: /app directory does not exist"
        exit 1
    fi
fi

echo ""
echo "🎯 Using project directory: $PROJECT_DIR"
echo ""

# Check if Python project exists
echo "🔍 DEBUG: Checking for __main__.py in $PROJECT_DIR..."
if [ ! -f "$PROJECT_DIR/__main__.py" ]; then
    echo "❌ ERROR: $PROJECT_DIR/__main__.py not found"
    echo "🔍 DEBUG: Directory listing of $PROJECT_DIR:"
    ls -la "$PROJECT_DIR" || true
    if [ -n "$GIT_REPO" ]; then
        echo "Repository was cloned but does not contain __main__.py"
    else
        echo "Please mount your Python project to /app volume or set GIT_REPO"
    fi
    exit 1
else
    echo "✅ Found __main__.py at $PROJECT_DIR/__main__.py"
fi

# Check and create .venv if needed
echo "🔍 DEBUG: Checking for virtual environment at $PROJECT_DIR/.venv..."
if [ ! -d "$PROJECT_DIR/.venv" ]; then
    echo "🐍 No .venv found, creating virtual environment..."
    echo "🔍 DEBUG: Python3 version: $(python3 --version 2>&1 || echo 'Python3 not found')"
    if ! python3 -m venv "$PROJECT_DIR/.venv" 2>&1; then
        echo "❌ ERROR: Failed to create virtual environment"
        exit 1
    fi
    echo "✅ Virtual environment created at $PROJECT_DIR/.venv"

    # Install requirements if requirements.txt exists
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        echo "📦 Installing dependencies from requirements.txt..."
        echo "🔍 DEBUG: Contents of requirements.txt:"
        cat "$PROJECT_DIR/requirements.txt" || true
        source "$PROJECT_DIR/.venv/bin/activate" || exit 1
        echo "🔍 DEBUG: Upgrading pip..."
        pip install --upgrade pip --quiet 2>&1 || echo "⚠️  Warning: pip upgrade failed"
        echo "🔍 DEBUG: Installing requirements..."
        if pip install -r "$PROJECT_DIR/requirements.txt" 2>&1; then
            echo "✅ Dependencies installed"
            echo "🔍 DEBUG: Installed packages:"
            pip list || true
        else
            echo "⚠️  WARNING: Some dependencies failed to install"
        fi
    else
        echo "⚠️  No requirements.txt found, skipping dependency installation"
    fi
else
    echo "✅ Virtual environment already exists at $PROJECT_DIR/.venv"
    echo "🔍 DEBUG: Checking installed packages:"
    source "$PROJECT_DIR/.venv/bin/activate" || exit 1
    pip list || true
fi

# Set VNC password (optional)
echo ""
echo "🔒 Configuring VNC security..."
mkdir -p /root/.vnc
if [ -n "$VNC_PASSWORD" ]; then
    echo "🔐 VNC authentication: enabled"
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    VNC_SECURITY_TYPE="VncAuth"
    echo "🔍 DEBUG: VNC password file created at /root/.vnc/passwd"
else
    echo "⚠️  VNC authentication: disabled (no password)"
    VNC_SECURITY_TYPE="None"
fi

# Set color depth (default to 16 for performance)
VNC_COLOR_DEPTH=${VNC_COLOR_DEPTH:-16}
echo "🔍 DEBUG: VNC Color Depth: $VNC_COLOR_DEPTH"
echo "🔍 DEBUG: Display settings: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"

# Start D-Bus (required for desktop environment)
echo ""
echo "🔧 Starting D-Bus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork 2>/dev/null || echo "⚠️  D-Bus may already be running"
sleep 1
echo "✅ D-Bus started"

# Start PulseAudio if audio is enabled
if [ "$ENABLE_AUDIO" = "true" ]; then
    echo ""
    echo "🔊 Starting PulseAudio..."
    pulseaudio --start --exit-idle-time=-1 &
    sleep 1
    echo "✅ PulseAudio started"
fi

echo ""
echo "🌐 Starting Xvnc (TigerVNC server with X) on port $VNC_PORT..."
echo "🔍 DEBUG: VNC Security Type: $VNC_SECURITY_TYPE"

# Use Xvnc directly instead of separate Xvfb and vncserver
# Build VNC command with conditional security flag
VNC_CMD="Xvnc $DISPLAY -geometry ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} -depth $VNC_COLOR_DEPTH -rfbport $VNC_PORT"

# Add password file or insecure flag
if [ -n "$VNC_PASSWORD" ]; then
    VNC_CMD="$VNC_CMD -PasswordFile /root/.vnc/passwd -SecurityTypes VncAuth"
    echo "🔍 DEBUG: Using password file for authentication"
else
    VNC_CMD="$VNC_CMD -SecurityTypes None"
    echo "🔍 DEBUG: Using no authentication (SecurityTypes=None)"
fi

VNC_CMD="$VNC_CMD -AlwaysShared -AcceptSetDesktopSize=0 -localhost no"
echo "🔍 DEBUG: VNC Command: $VNC_CMD"

# Start VNC server in background
eval "$VNC_CMD" > /tmp/vncserver.log 2>&1 &
VNC_PID=$!
echo "🔍 DEBUG: Xvnc PID: $VNC_PID"

# Wait for VNC server to start
sleep 3

# Check if process is still running
if ! ps -p $VNC_PID > /dev/null 2>&1; then
    echo "❌ ERROR: VNC server process died immediately"
    echo "🔍 DEBUG: VNC server log:"
    cat /tmp/vncserver.log 2>/dev/null || echo "No log file found"
    exit 1
fi

# Check if VNC server is running
echo "🔍 DEBUG: Checking VNC server status..."
if ps -p $VNC_PID > /dev/null; then
    echo "✅ VNC server process running (PID: $VNC_PID)"
else
    echo "⚠️  WARNING: VNC server process not found"
fi

# Check if VNC port is listening
if netstat -tuln 2>/dev/null | grep -q ":$VNC_PORT "; then
    echo "✅ VNC server listening on port $VNC_PORT"
else
    echo "⚠️  WARNING: VNC server not listening on port $VNC_PORT"
    echo "🔍 DEBUG: VNC server log:"
    cat /tmp/vncserver.log 2>/dev/null || echo "No log file found"
    echo "🔍 DEBUG: Checking for VNC log files:"
    ls -la /root/.vnc/*.log 2>/dev/null || echo "No VNC log files found"
    if [ -f "/root/.vnc/$(hostname):1.log" ]; then
        echo "🔍 DEBUG: VNC server log content:"
        cat "/root/.vnc/$(hostname):1.log"
    fi
fi

echo ""
echo "🌐 Starting noVNC web interface on port $NOVNC_PORT..."

# Check for noVNC installation and find the correct path
NOVNC_WEB_DIR=""
if [ -d "/usr/share/novnc" ]; then
    NOVNC_WEB_DIR="/usr/share/novnc"
    echo "✅ Found noVNC at /usr/share/novnc"
elif [ -d "/usr/share/novnc/vnc" ]; then
    NOVNC_WEB_DIR="/usr/share/novnc/vnc"
    echo "✅ Found noVNC at /usr/share/novnc/vnc"
else
    echo "⚠️  WARNING: noVNC directory not found at /usr/share/novnc"
    echo "🔍 DEBUG: Searching for noVNC..."
    NOVNC_WEB_DIR=$(find /usr -name "vnc.html" -o -name "vnc_lite.html" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
    if [ -n "$NOVNC_WEB_DIR" ]; then
        echo "✅ Found noVNC at $NOVNC_WEB_DIR"
    else
        echo "❌ ERROR: noVNC not found, using /usr/share/novnc as fallback"
        NOVNC_WEB_DIR="/usr/share/novnc"
    fi
fi

# List available HTML files for debugging
echo "🔍 DEBUG: Available noVNC files in $NOVNC_WEB_DIR:"
ls -la "$NOVNC_WEB_DIR"/*.html 2>/dev/null || echo "No HTML files found"

# Check if vnc.html exists, if not try vnc_lite.html
if [ ! -f "$NOVNC_WEB_DIR/vnc.html" ]; then
    if [ -f "$NOVNC_WEB_DIR/vnc_lite.html" ]; then
        echo "⚠️  vnc.html not found, creating symlink to vnc_lite.html"
        ln -sf "vnc_lite.html" "$NOVNC_WEB_DIR/vnc.html" 2>/dev/null || true
        if [ -f "$NOVNC_WEB_DIR/vnc.html" ]; then
            echo "✅ Created symlink to vnc_lite.html"
        else
            echo "⚠️  WARNING: Failed to create symlink, will use vnc_lite.html directly"
        fi
    else
        echo "❌ ERROR: Neither vnc.html nor vnc_lite.html found in $NOVNC_WEB_DIR"
        echo "🔍 DEBUG: Directory contents:"
        ls -la "$NOVNC_WEB_DIR" || true
    fi
else
    echo "✅ Found vnc.html"
fi

# Create index.html that redirects to vnc.html if it doesn't exist
if [ ! -f "$NOVNC_WEB_DIR/index.html" ]; then
    echo "📄 Creating index.html redirect to vnc.html"
    cat > "$NOVNC_WEB_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0; url=vnc.html">
    <title>noVNC</title>
</head>
<body>
    <p>Redirecting to <a href="vnc.html">vnc.html</a>...</p>
    <script>window.location.href = 'vnc.html';</script>
</body>
</html>
EOF
    echo "✅ Created index.html"
fi

# Verify that we have at least one HTML file to serve
if [ ! -f "$NOVNC_WEB_DIR/vnc.html" ] && [ ! -f "$NOVNC_WEB_DIR/vnc_lite.html" ]; then
    echo "❌ ERROR: No noVNC HTML file found. Cannot start websockify."
    exit 1
fi

echo "🔍 DEBUG: noVNC Command: websockify --web=$NOVNC_WEB_DIR $NOVNC_PORT localhost:$VNC_PORT"
# Start websockify in background
websockify --web="$NOVNC_WEB_DIR" $NOVNC_PORT localhost:$VNC_PORT > /tmp/novnc.log 2>&1 &
NOVNC_PID=$!
echo "🔍 DEBUG: noVNC PID: $NOVNC_PID"

# Wait for websockify to start
sleep 3

# Check if process is still running
if ! ps -p $NOVNC_PID > /dev/null 2>&1; then
    echo "❌ ERROR: websockify process died immediately"
    echo "🔍 DEBUG: websockify log:"
    cat /tmp/novnc.log 2>/dev/null || echo "No log file found"
    exit 1
fi

# Check if noVNC is running
if ps -p $NOVNC_PID > /dev/null; then
    echo "✅ noVNC started successfully (PID: $NOVNC_PID)"
else
    echo "❌ ERROR: noVNC failed to start"
    cat /tmp/novnc.log 2>/dev/null || echo "No noVNC log found"
fi

# Check if noVNC port is listening
if netstat -tuln 2>/dev/null | grep -q ":$NOVNC_PORT "; then
    echo "✅ noVNC listening on port $NOVNC_PORT"
else
    echo "⚠️  WARNING: noVNC not listening on port $NOVNC_PORT"
fi

# Test if vnc.html is accessible (wait a bit for websockify to fully start)
sleep 1
echo "🔍 DEBUG: Testing noVNC accessibility..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$NOVNC_PORT/vnc.html" | grep -q "200\|301\|302"; then
    echo "✅ vnc.html is accessible"
elif curl -s -o /dev/null -w "%{http_code}" "http://localhost:$NOVNC_PORT/" | grep -q "200\|301\|302"; then
    echo "✅ noVNC root is accessible (try http://your-ip:$NOVNC_PORT/ instead of /vnc.html)"
else
    echo "⚠️  WARNING: Could not verify noVNC accessibility via HTTP test"
    echo "🔍 DEBUG: HTTP response codes:"
    echo "  Root (/): $(curl -s -o /dev/null -w '%{http_code}' http://localhost:$NOVNC_PORT/ 2>/dev/null || echo 'failed')"
    echo "  /vnc.html: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:$NOVNC_PORT/vnc.html 2>/dev/null || echo 'failed')"
fi

# Activate Python virtual environment
echo ""
echo "🐍 Activating Python virtual environment..."
echo "🔍 DEBUG: Changing directory to $PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1
echo "🔍 DEBUG: Current directory: $(pwd)"
echo "🔍 DEBUG: Sourcing $PROJECT_DIR/.venv/bin/activate"
if [ ! -f "$PROJECT_DIR/.venv/bin/activate" ]; then
    echo "❌ ERROR: Virtual environment activation script not found"
    exit 1
fi
source "$PROJECT_DIR/.venv/bin/activate" || exit 1

# Get Python version
PYTHON_VERSION=$(python --version 2>&1)
echo "✅ Using: $PYTHON_VERSION"
echo "🔍 DEBUG: Python path: $(which python)"
echo "🔍 DEBUG: Pip version: $(pip --version)"

# Check if .env exists in project directory
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "✅ Found $PROJECT_DIR/.env file (loaded by Python script)"
    echo "🔍 DEBUG: .env file contents (sensitive data hidden):"
    grep -v -E '^[A-Z_]+=.+' "$PROJECT_DIR/.env" || echo "(All lines contain assignments)"
fi

echo ""
echo "========================================"
echo "🎉 VNC Bridge Ready!"
echo "========================================"
echo "🌐 Access via browser: http://localhost:$NOVNC_PORT"
if [ -n "$VNC_PASSWORD" ]; then
    echo "🔐 VNC Password: ******* (protected)"
else
    echo "⚠️  VNC Password: none (open access)"
fi
echo "🖥️  Display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} @ ${VNC_FPS}fps"
echo "🔊 Audio: $ENABLE_AUDIO"
echo "📂 Project Directory: $PROJECT_DIR"
echo "========================================"
echo ""
echo "🖥️  Starting Desktop Environment (LXDE)..."
echo ""

# Create desktop autostart script for Python application
mkdir -p /root/.config/autostart
AUTOSTART_SCRIPT="/root/.config/autostart/python-app.desktop"
cat > "$AUTOSTART_SCRIPT" << EOF
[Desktop Entry]
Type=Application
Name=Python Application
Comment=Start Python Application
Exec=lxterminal -e bash -c 'cd "$PROJECT_DIR" && source "$PROJECT_DIR/.venv/bin/activate" && python __main__.py; echo ""; echo "Application exited. Press any key to close..."; read'
Icon=utilities-terminal
Terminal=false
Categories=Application;
X-GNOME-Autostart-enabled=true
EOF
chmod +x "$AUTOSTART_SCRIPT" 2>/dev/null || true

# Create startup script for Python app in terminal
PYTHON_APP_SCRIPT="/root/start_python_app.sh"
cat > "$PYTHON_APP_SCRIPT" << EOF
#!/bin/bash
cd "$PROJECT_DIR" || exit 1
source "$PROJECT_DIR/.venv/bin/activate" || exit 1
echo "🚀 Starting Python application: __main__.py"
python __main__.py
EXIT_CODE=\$?
echo ""
echo "Application exited with code: \$EXIT_CODE"
echo "Press any key to close..."
read
EOF
chmod +x "$PYTHON_APP_SCRIPT"

# Create desktop shortcut
DESKTOP_SHORTCUT="/root/Desktop/Python-App.desktop"
cat > "$DESKTOP_SHORTCUT" << EOF
[Desktop Entry]
Type=Application
Name=Python Application
Comment=Run Python Application
Exec=lxterminal -e "$PYTHON_APP_SCRIPT"
Icon=utilities-terminal
Terminal=false
Categories=Application;
EOF
chmod +x "$DESKTOP_SHORTCUT" 2>/dev/null || true

echo "🔍 DEBUG: Starting LXDE desktop environment..."

# Set environment for desktop
export DISPLAY=$DISPLAY
export HOME=/root
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Start LXDE session
echo "🔍 DEBUG: Launching LXDE..."
startlxde > /tmp/lxde.log 2>&1 &
DESKTOP_PID=$!

# Wait for desktop to start
sleep 5

# Check if desktop is running
if ps -p $DESKTOP_PID > /dev/null 2>&1; then
    echo "✅ Desktop environment started (PID: $DESKTOP_PID)"
else
    echo "⚠️  WARNING: Desktop environment may not have started properly"
    echo "🔍 DEBUG: Desktop log:"
    cat /tmp/lxde.log 2>/dev/null || echo "No log file found"
fi

# Optionally start Python app in terminal (can be disabled if using autostart)
if [ "${START_PYTHON_APP:-true}" = "true" ]; then
    echo ""
    echo "🚀 Starting Python application in terminal..."
    sleep 2  # Wait a bit for desktop to be ready
    
    # Start Python app in lxterminal
    lxterminal -e bash -c "cd $PROJECT_DIR && source $PROJECT_DIR/.venv/bin/activate && python __main__.py; echo ''; echo 'Application exited. Press any key to close...'; read" &
    PYTHON_APP_PID=$!
    echo "✅ Python application started in terminal (PID: $PYTHON_APP_PID)"
fi

# Cleanup function
cleanup() {
    echo ""
    echo "Shutting down..."
    kill $DESKTOP_PID 2>/dev/null || true
    kill $PYTHON_APP_PID 2>/dev/null || true
    kill $NOVNC_PID 2>/dev/null || true
    kill $VNC_PID 2>/dev/null || true
    if [ "$ENABLE_AUDIO" = "true" ]; then
        pulseaudio --kill 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep container running - wait for desktop or Python app
if [ -n "$PYTHON_APP_PID" ]; then
    wait $PYTHON_APP_PID 2>/dev/null || wait $DESKTOP_PID 2>/dev/null || true
else
    wait $DESKTOP_PID 2>/dev/null || true
fi
