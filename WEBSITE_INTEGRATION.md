# noVNC Website Integration

Anleitung zur Einbindung des Python VNC Containers in deine Website.

## Übersicht

Es gibt **3 Methoden** zur Integration:

1. **iFrame Einbindung** (Einfachste Methode)
2. **noVNC JavaScript API** (Volle Kontrolle)
3. **Reverse Proxy mit Subdomain** (Professionellste Lösung)

---

## Methode 1: iFrame Einbindung (Schnellste Lösung)

### 1.1 Basis-Integration

Einfachstes Beispiel - direkter iFrame:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Mein Python Spiel</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            overflow: hidden;
        }
        #vnc-container {
            width: 100vw;
            height: 100vh;
        }
    </style>
</head>
<body>
    <iframe
        id="vnc-container"
        src="http://DEINE-BANANAPI-IP:6080/vnc.html?autoconnect=true&resize=scale"
        frameborder="0"
        allowfullscreen>
    </iframe>
</body>
</html>
```

**Ersetze:** `DEINE-BANANAPI-IP` mit der IP deines BananaPi (z.B. `192.168.1.100`)

### 1.2 Mit Passwort-Automatik

noVNC unterstützt Passwort-Übergabe via URL-Parameter:

```html
<iframe
    src="http://BANANAPI-IP:6080/vnc.html?autoconnect=true&resize=scale&password=DEIN_VNC_PASSWORT"
    width="100%"
    height="800px"
    frameborder="0">
</iframe>
```

⚠️ **Sicherheitswarnung:** Passwort ist im HTML sichtbar! Nur für private/lokale Netze!

### 1.3 Responsive Integration

Für bessere mobile Unterstützung:

```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Python Hangman Spiel</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: Arial, sans-serif;
            background: #1a1a1a;
        }

        .header {
            background: #333;
            color: white;
            padding: 1rem;
            text-align: center;
        }

        .game-container {
            position: relative;
            width: 100%;
            height: calc(100vh - 60px);
        }

        iframe {
            width: 100%;
            height: 100%;
            border: none;
        }

        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: white;
            font-size: 1.5rem;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎮 Python Hangman Spiel</h1>
    </div>

    <div class="game-container">
        <div class="loading" id="loading">Lade Spiel...</div>
        <iframe
            src="http://BANANAPI-IP:6080/vnc.html?autoconnect=true&resize=scale"
            onload="document.getElementById('loading').style.display='none'">
        </iframe>
    </div>
</body>
</html>
```

---

## Methode 2: noVNC JavaScript API (Erweitert)

Für volle Kontrolle über die VNC-Verbindung mit eigenem UI.

### 2.1 HTML Setup

```html
<!DOCTYPE html>
<html>
<head>
    <title>Custom VNC Client</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            background: #000;
            font-family: Arial, sans-serif;
        }

        #toolbar {
            background: #2c3e50;
            padding: 10px;
            color: white;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        #screen {
            display: flex;
            justify-content: center;
            align-items: center;
            height: calc(100vh - 50px);
            background: #1a1a1a;
        }

        button {
            background: #3498db;
            color: white;
            border: none;
            padding: 8px 16px;
            margin: 0 5px;
            cursor: pointer;
            border-radius: 4px;
        }

        button:hover {
            background: #2980b9;
        }

        button:disabled {
            background: #7f8c8d;
            cursor: not-allowed;
        }

        #status {
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div id="toolbar">
        <div>
            <span id="status">Getrennt</span>
        </div>
        <div>
            <button id="connectBtn" onclick="connect()">Verbinden</button>
            <button id="disconnectBtn" onclick="disconnect()" disabled>Trennen</button>
            <button onclick="sendCtrlAltDel()">Strg+Alt+Entf</button>
            <button onclick="toggleFullscreen()">Vollbild</button>
        </div>
    </div>

    <div id="screen"></div>

    <!-- noVNC Core Library -->
    <script type="module">
        import RFB from 'http://BANANAPI-IP:6080/core/rfb.js';

        let rfb;
        const password = 'DEIN_VNC_PASSWORT'; // Oder via Prompt

        window.connect = function() {
            const host = 'BANANAPI-IP';
            const port = 6080;
            const path = 'websockify';

            const url = `ws://${host}:${port}/${path}`;

            // RFB Objekt erstellen
            rfb = new RFB(document.getElementById('screen'), url, {
                credentials: { password: password },
                shared: true,
                repeaterID: '',
            });

            // Event Handlers
            rfb.addEventListener("connect", onConnected);
            rfb.addEventListener("disconnect", onDisconnected);
            rfb.addEventListener("securityfailure", onSecurityFailure);

            // Scaling
            rfb.scaleViewport = true;
            rfb.resizeSession = false;

            document.getElementById('connectBtn').disabled = true;
            document.getElementById('status').textContent = 'Verbinde...';
        }

        window.disconnect = function() {
            if (rfb) {
                rfb.disconnect();
            }
        }

        window.sendCtrlAltDel = function() {
            if (rfb) {
                rfb.sendCtrlAltDel();
            }
        }

        window.toggleFullscreen = function() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        }

        function onConnected() {
            document.getElementById('status').textContent = '✅ Verbunden';
            document.getElementById('connectBtn').disabled = true;
            document.getElementById('disconnectBtn').disabled = false;
        }

        function onDisconnected() {
            document.getElementById('status').textContent = '❌ Getrennt';
            document.getElementById('connectBtn').disabled = false;
            document.getElementById('disconnectBtn').disabled = true;
        }

        function onSecurityFailure() {
            document.getElementById('status').textContent = '⚠️ Authentifizierung fehlgeschlagen';
            document.getElementById('connectBtn').disabled = false;
        }

        // Auto-connect beim Laden
        // window.addEventListener('load', connect);
    </script>
</body>
</html>
```

### 2.2 Passwort-Dialog Version

Sicherer - Passwort wird abgefragt:

```javascript
window.connect = function() {
    const password = prompt('VNC Passwort eingeben:');
    if (!password) return;

    const url = 'ws://BANANAPI-IP:6080/websockify';

    rfb = new RFB(document.getElementById('screen'), url, {
        credentials: { password: password }
    });

    // ... rest wie oben
}
```

---

## Methode 3: Reverse Proxy (Produktion)

Professionellste Lösung mit HTTPS und Subdomain.

### 3.1 nginx Reverse Proxy

Auf deinem Webserver (nginx):

```nginx
# /etc/nginx/sites-available/vnc-game

server {
    listen 80;
    server_name game.deine-domain.de;

    # Redirect to HTTPS (optional aber empfohlen)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name game.deine-domain.de;

    # SSL Zertifikat (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/game.deine-domain.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/game.deine-domain.de/privkey.pem;

    location / {
        proxy_pass http://BANANAPI-IP:6080;
        proxy_http_version 1.1;

        # WebSocket Support (wichtig für noVNC!)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Standard Proxy Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts für lange Verbindungen
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

Aktivieren:
```bash
sudo ln -s /etc/nginx/sites-available/vnc-game /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3.2 Website Integration mit Reverse Proxy

Jetzt kannst du einfach deine Subdomain nutzen:

```html
<iframe
    src="https://game.deine-domain.de/vnc.html?autoconnect=true&resize=scale"
    width="100%"
    height="800px">
</iframe>
```

### 3.3 Apache Reverse Proxy Alternative

Falls du Apache nutzt:

```apache
<VirtualHost *:443>
    ServerName game.deine-domain.de

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/game.deine-domain.de/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/game.deine-domain.de/privkey.pem

    # WebSocket Proxy
    ProxyPreserveHost On
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*)           ws://BANANAPI-IP:6080/$1 [P,L]
    RewriteCond %{HTTP:Upgrade} !=websocket [NC]
    RewriteRule /(.*)           http://BANANAPI-IP:6080/$1 [P,L]

    ProxyPass / http://BANANAPI-IP:6080/
    ProxyPassReverse / http://BANANAPI-IP:6080/

    ProxyTimeout 7200
</VirtualHost>
```

Erforderliche Module:
```bash
sudo a2enmod proxy proxy_http proxy_wstunnel rewrite ssl
sudo systemctl restart apache2
```

---

## Sicherheit

### CORS / Cross-Origin Issues

Falls deine Website auf einer anderen Domain läuft, könnte CORS Probleme machen.

**Lösung 1:** nginx Header hinzufügen

```nginx
location / {
    # ... andere proxy settings ...

    add_header Access-Control-Allow-Origin "https://deine-website.de";
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    add_header Access-Control-Allow-Headers "Authorization";
}
```

**Lösung 2:** Docker Container Config anpassen

In `docker-compose.yml`:

```yaml
environment:
  - NOVNC_CORS_ALLOW_ORIGIN=https://deine-website.de
```

Und in `entrypoint.sh` websockify mit CORS starten:

```bash
websockify --web=/usr/share/novnc/ \
    --ssl-only \
    --cert=/path/to/cert.pem \
    --key=/path/to/key.pem \
    $NOVNC_PORT localhost:$VNC_PORT
```

### HTTP Basic Auth (Zusätzlicher Schutz)

nginx mit Basic Auth:

```nginx
location / {
    auth_basic "Gesicherter Bereich";
    auth_basic_user_file /etc/nginx/.htpasswd;

    # ... proxy settings ...
}
```

Passwort-Datei erstellen:
```bash
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd spieler
```

---

## Testing & Debugging

### Verbindungstest

```bash
# Test ob noVNC Port erreichbar ist
curl http://BANANAPI-IP:6080

# WebSocket Test
wscat -c ws://BANANAPI-IP:6080/websockify
```

### Browser Console

Öffne Developer Tools (F12) und prüfe:
- Network Tab → WebSocket Verbindungen
- Console → Fehlermeldungen

### Häufige Probleme

**iFrame lädt nicht:**
- Prüfe `X-Frame-Options` Header
- Lösung: In nginx `add_header X-Frame-Options "SAMEORIGIN";`

**WebSocket Verbindung fehlschlägt:**
- Firewall blockiert Port 6080
- Reverse Proxy fehlt WebSocket-Support

**Passwort funktioniert nicht:**
- VNC_PASSWORD in `.env` korrekt?
- Container neu starten: `docker-compose restart`

---

## Performance-Tipps

### Kompression aktivieren

In nginx:

```nginx
location / {
    gzip on;
    gzip_types text/html application/javascript text/css;

    # ... proxy settings ...
}
```

### Client-seitige Optimierungen

```javascript
// Bei langsamer Verbindung
rfb.qualityLevel = 6; // 0-9, niedriger = bessere Kompression
rfb.compressionLevel = 2; // 0-9, höher = mehr Kompression
```

---

## Beispiel-Implementierung

Vollständiges Beispiel im Repo erstellen:

```bash
cd python-vnc-bridge
mkdir website-example
```

Siehe `website-example/` Ordner für lauffähige Beispiele aller 3 Methoden.

---

## Checkliste Website-Integration

- [ ] BananaPi IP-Adresse notiert
- [ ] noVNC Port (6080) in Firewall freigegeben
- [ ] VNC_PASSWORD gesetzt
- [ ] Methode gewählt (iFrame / JS API / Reverse Proxy)
- [ ] HTML-Datei erstellt und getestet
- [ ] Optional: HTTPS/SSL konfiguriert
- [ ] Optional: Basic Auth eingerichtet
- [ ] Browser-Test durchgeführt

---

## Support

Bei Problemen:
1. Container Logs prüfen: `docker-compose logs -f`
2. Browser Console auf Fehler checken
3. Firewall/Router Port-Forwarding prüfen
4. Issue im Repository öffnen
