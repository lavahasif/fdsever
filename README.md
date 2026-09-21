<h1 align="center">
  <br>
  🌐 FDServer 5.0
  <br>
</h1>

<h4 align="center">A powerful, all-in-one local network server and utility suite built with Flutter & Shadcn UI.</h4>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44-blue?logo=flutter" alt="Flutter 3.44">
  <img src="https://img.shields.io/badge/Dart-3.12-blue?logo=dart" alt="Dart 3.12">
  <img src="https://img.shields.io/badge/Shadcn_UI-0.57-black" alt="Shadcn UI">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-green" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-getting-started">Getting Started</a> •
  <a href="#-modules">Modules</a> •
  <a href="#-api-reference">API Reference</a> •
  <a href="#-build--release">Build & Release</a> •
  <a href="#-testing">Testing</a>
</p>

---

## 📋 Overview

**FDServer** is a feature-rich, multi-platform Flutter application that turns your device into a local network hub. It combines a Shelf-based HTTP web server, TCP port scanner, WhatsApp direct messenger, knowledge base notes, tutorial manager, real-time WebSocket hub, and file transfer — all inside a beautiful, responsive Shadcn UI interface.

Whether you're a developer testing local APIs, a sysadmin probing network hosts, or someone who simply wants to share files over WiFi without any cloud dependency — FDServer has you covered.

---

## ✨ Features

| Module | Key Capabilities |
|--------|-----------------|
| 🖥️ **Web Server** | Shelf HTTP server, custom routes, live request logs, copy/open endpoints |
| 🌐 **Network Scanner** | IP discovery, port probing, subnet scan, interface viewer |
| 💬 **WhatsApp Direct** | Contact-free messaging, country code presets, message templates, history |
| 📝 **Notes & KB** | CRUD notes, search, link attachment, exposed via server API |
| 📚 **Tutorials** | Category-filtered tutorial cards, quick links, search |
| 📡 **Realtime Hub** | WebSocket client/server, URL auto-detection, live message feed |
| 📤 **File Transfer** | Pick & share files over LAN, upload progress, delete & manage |
| ⚙️ **Settings** | Theme toggle, IP/port presets, timeout configuration |

---

## 🚀 Getting Started

### Prerequisites

| Requirement | Version |
|-------------|---------|
| Flutter SDK | ≥ 3.44.0 |
| Dart SDK | ≥ 3.12.1 |
| Android SDK | API 21+ (Android 5.0+) |
| Java (JDK) | 17+ (for Android builds) |
| Git | any recent version |

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/lavahasif/fdservers.git
cd fdservers

# 2. Install dependencies
flutter pub get

# 3. Run in debug mode (connect a device or start an emulator first)
flutter run

# 4. Run on a specific platform
flutter run -d android
flutter run -d windows
flutter run -d macos
```

### First Launch

On first launch, the app opens to the **Dashboard** with all services stopped. The server is **not** auto-started — you must tap **Start Server** to begin serving.

---

## 🗺️ Navigation

FDServer uses a **responsive layout**:

- **Tablet / Desktop (≥768px wide):** Persistent left sidebar with all 9 modules
- **Mobile (< 768px):** Bottom navigation bar (5 primary tabs) + sidebar access on tablet

```
┌──────────────────────────────────────────────────┐
│  FDServer                    [Server: Inactive]   │  ← App Header
├────────────┬─────────────────────────────────────┤
│            │                                     │
│  Dashboard │         Main Content Area           │
│  Web Server│                                     │
│  Scanner   │   (Switches based on sidebar        │
│  WhatsApp  │    or bottom nav selection)         │
│  Notes     │                                     │
│  Tutorials │                                     │
│  Realtime  │                                     │
│  Files     │                                     │
│  Settings  │                                     │
│            │                                     │
└────────────┴─────────────────────────────────────┘
```

---

## 📦 Modules

### 1. 🖥️ Dashboard

The central overview of FDServer's status.

**What you see:**
- **Hero Banner** — current server URL (when running) and quick Start/Stop button
- **4 Stat Cards** — Web Server status, Local IP, Notes count, Tutorials count
- **Quick Access Tools** — shortcut buttons to Port Scanner, WhatsApp, Realtime, Files, Settings
- **Recent Server Activity** — live log preview (last 5 requests)

**Quick Actions:**
| Button | Action |
|--------|--------|
| `Start Server` / `Stop Server` | Toggle the Shelf HTTP server |
| `Open Web Controller` | Navigate to Web Server module |
| `Port Scanner` | Navigate to Scanner |
| `WhatsApp Direct` | Navigate to WhatsApp |

---

### 2. 🌐 Web Server

Control your local HTTP server and explore its routes.

#### Starting the Server

1. Set **Bind Address** (default: `0.0.0.0` — listens on all interfaces)
2. Set **Port** (default: `8081`)
3. Press **▶ Start Server** — the button turns red and displays the active URL
4. Share the URL (e.g., `http://192.168.1.5:8081`) with devices on the same WiFi

> ⚠️ **Note:** If the server fails to start, check that the port is not already in use and that no firewall is blocking it.

#### Available Endpoints

| Route | Type | Description |
|-------|------|-------------|
| `/` | HTML | Home page (served from `assets/files/index.html`) |
| `/home` | HTML | Alias for home page |
| `/notes` | HTML | Rendered notes browser page |
| `/files` | HTML | Shared files directory listing |
| `/bim` | HTML | BIM architecture demo page |
| `/upload` | HTML | Web-based file upload portal |
| `/bootstrap` | HTML | Bootstrap self-serve page |
| `/api/status` | JSON | Server health/status JSON endpoint |
| `/api/notes` | JSON | Notes data as JSON array |
| `/api/upload` | POST | Multipart file upload target |

#### Copy & Open Endpoints

Each route row has two buttons:
- **📋 Copy** — copies the full URL to clipboard
- **↗ Open** — launches the URL in your device's default browser (only when server is running)

#### Live Request Logs

The **Live Server Requests** table shows the last 15 HTTP requests with:
- HTTP status code (green = success, red = error)
- Method (GET / POST)
- Request path
- Timestamp (HH:MM:SS)
- Client IP address

---

### 3. 🌐 Network & Port Scanner

Discover devices and probe open ports on your local network.

#### Interface Cards

The top section shows all detected **network interfaces** on your device:
- WiFi IP (e.g., `192.168.1.100`)
- Loopback (`127.0.0.1`)
- Click the **↓ arrow** button on any interface to auto-fill it as the scan target

#### Scanning Modes

| Button | Action |
|--------|--------|
| **Probe Target** | Tests TCP connectivity to the specified IP:Port |
| **Scan Common Ports** | Scans well-known ports (22, 80, 443, 3306, 5432, 8080, 8081, etc.) on the target IP |
| **Scan Subnet** | Scans all `x.x.x.1–254` addresses on the same `/24` subnet to discover live devices |

#### Scan Results

Each discovered device/result is displayed as a card showing:
- Reachability indicator (✅ green laptop icon = reachable)
- IP address
- Port status badges (`OPEN` green / `CLOSED` grey)
- **Copy IP** button
- **Browse** button — opens `http://{ip}:{firstOpenPort}` in browser

> 💡 **Tip:** Use **Refresh Interfaces** to reload your device's network interface list after connecting to a new WiFi network.

---

### 4. 💬 WhatsApp Direct Message

Open a WhatsApp chat with any phone number **without saving it as a contact**.

#### How to Use

1. **Enter the phone number** in international format (e.g., `919876543210` for India)
   - Or click **Paste** to paste from clipboard (digits only, cleaned automatically)
   - Or click a **country code chip** to prepend the code to your current number:
     - `+91 (IN)` — India
     - `+1 (US)` — United States
     - `+44 (UK)` — United Kingdom
     - `+971 (UAE)` — UAE
     - `+966 (KSA)` — Saudi Arabia

2. **Type a message** (optional) — or pick a quick template:
   - *"Hi there!"*
   - *"Here is the link for our meeting."*
   - *"Please share the document."*

3. **Choose how to open:**
   - **🟢 Open WhatsApp** — launches the native WhatsApp app with pre-filled number & message
   - **🌐 Open via Web (wa.me)** — opens `https://wa.me/{number}?text={message}` in browser (works without WhatsApp installed)

#### Recent Numbers

Every number you message is saved in **Recent Numbers** history for fast re-use:
- **Use** — re-fills the phone field
- **Copy** — copies the number to clipboard
- **Clear History** — wipes all saved numbers

---

### 5. 📝 Notes & Knowledge Base

A private, searchable notebook that also exposes your notes via the web server API.

#### Adding a Note

1. Click **Add Note** button
2. Fill in the dialog:
   - **Title** (required)
   - **Note body** — your content
   - **Link** (optional) — a URL associated with the note
3. Click **Save Note**

#### Managing Notes

- **Search** — filter notes in real-time by title or content
- **Edit** (pencil icon) — modify an existing note
- **Delete** (trash icon) — remove a note with confirmation

#### Web API Integration

When the web server is running, your notes are automatically available at:
- `http://{your-ip}:{port}/notes` — rendered HTML page
- `http://{your-ip}:{port}/api/notes` — raw JSON array

---

### 6. 📚 Tutorials Manager

Organize and browse learning resources, links, and how-to guides.

#### Adding a Tutorial

1. Click **Add Tutorial**
2. Fill in:
   - **Title**
   - **Category** (e.g., Network, Flutter, Dart, Linux, DevOps)
   - **Description**
   - **Link** (URL to external resource)
3. Click **Save**

#### Browsing Tutorials

- **Category Filter** — filter by category via chip buttons at the top
- **Search** — real-time search by title or description
- **Open Link** — launches the tutorial URL in the default browser
- **Delete** — removes a tutorial entry

---

### 7. 📡 Realtime WebSocket Hub

Send and receive real-time messages over WebSocket connections.

#### Connection Modes

| Mode | Description |
|------|-------------|
| **Client** | Connect to an existing WebSocket server (e.g., `ws://192.168.1.5:8090`) |
| **Server** | Host your own WebSocket server and accept incoming connections |

#### Using as Client

1. Enter the WebSocket URL (e.g., `ws://192.168.1.100:8090`)
2. Click **Connect**
3. Type a message and press **Send**
4. Received messages appear in the feed with timestamps

#### Using as Server

1. Set the server port (default: `8090`)
2. Click **Start WS Server**
3. Share the WebSocket URL shown (e.g., `ws://192.168.1.5:8090`)
4. Connected clients can send and receive messages

#### URL Auto-Detection

If a received message contains a URL (e.g., `https://example.com` or `http://192.168.1.1:8081`), it is automatically underlined and tappable — clicking opens it in the browser.

---

### 8. 📤 File Transfer

Share files over your local network using the built-in HTTP server.

#### Uploading Files

1. Ensure the **Web Server is running**
2. Click **Pick File(s)** to select files from your device
3. Selected files are listed with their size
4. Click **Upload / Share** — files are served via the web server

#### Accessing Uploaded Files

Other devices on the same WiFi can access:
```
http://{your-ip}:{port}/files
```

#### File Management

- Each file entry shows its name, size, and upload status
- **Delete** (trash icon) — removes the file from the transfer list
- **Share** (share icon) — copies the direct download link to clipboard

---

### 9. ⚙️ Settings

Configure global application preferences.

#### Default Network Parameters

| Setting | Default | Description |
|---------|---------|-------------|
| Favorite / Preset IP | `127.0.0.1` | Pre-filled target IP across modules |
| Default Port | `8069` | Pre-filled port across modules |
| Probe Timeout (ms) | `5000` | Max wait time for a TCP connection probe |
| Secondary Timeout (ms) | `5000` | Fallback timeout for scanner operations |

Click **💾 Save Preferences** to persist changes.

#### Visual Appearance (Theme)

Choose your preferred color theme:
- **System Default** — follows OS light/dark setting
- **Light Theme** — always light
- **Dark Theme** — always dark (default look: Zinc dark, `#09090B` background)

#### About

Displays app version info and dependency stack:
- Flutter 3.44 · Dart 3.12 · Shadcn UI 0.57 · Shelf HTTP 1.4

---

## 🔌 API Reference

When the web server is running, the following endpoints are available:

### `GET /api/status`

Returns server health information.

**Response:**
```json
{
  "status": "online",
  "server": "FDServer 5.0 (Flutter)",
  "timestamp": "2026-09-19T00:00:00.000Z",
  "port": 8081
}
```

### `GET /api/notes`

Returns all saved notes as a JSON array.

**Response:**
```json
[
  {
    "id": "abc123",
    "title": "My Note",
    "note": "Note body content",
    "link": "https://example.com",
    "createdAt": "2026-09-19T00:00:00.000Z"
  }
]
```

### `POST /api/upload`

Accepts raw file bytes for upload.

**Response:**
```json
{
  "success": true,
  "bytesReceived": 204800,
  "message": "File uploaded successfully to FDServer"
}
```

---

## 🏗️ Project Structure

```
lib/
├── main.dart                          # App entry point, providers setup, ShadApp
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # Shared constants (ports, timeouts, keys)
│   ├── models/
│   │   ├── network_device.dart        # Scanned device model
│   │   ├── note_item.dart             # Note data model (with JSON serialization)
│   │   ├── socket_message.dart        # WebSocket message model + URL extractor
│   │   └── tutorial_item.dart         # Tutorial data model
│   ├── services/
│   │   ├── file_transfer_service.dart # File pick, serve, and management
│   │   ├── network_service.dart       # IP interfaces, TCP probe, subnet scan
│   │   ├── socket_service.dart        # WebSocket client/server management
│   │   ├── storage_service.dart       # SharedPreferences persistence layer
│   │   ├── web_server_service.dart    # Shelf HTTP server, routes, logging
│   │   └── whatsapp_service.dart      # wa.me URL builder, number sanitizer
│   └── theme/
│       └── app_theme.dart             # ShadThemeData light & dark configurations
│
├── features/
│   ├── dashboard/screens/             # Overview cards, quick access, activity log
│   ├── file_transfer/
│   │   ├── providers/                 # FileTransferProvider (state management)
│   │   └── screens/                   # File picker UI, upload list, progress
│   ├── network_scanner/
│   │   ├── providers/                 # ScannerProvider (scanning state)
│   │   └── screens/                   # Interface cards, probe UI, results list
│   ├── notes/
│   │   ├── providers/                 # NotesProvider (CRUD, search)
│   │   └── screens/                   # Notes list, add/edit dialog, search bar
│   ├── realtime/
│   │   ├── providers/                 # RealtimeProvider (WS connection state)
│   │   └── screens/                   # Connection form, message feed
│   ├── settings/
│   │   ├── providers/                 # SettingsProvider (theme, network prefs)
│   │   └── screens/                   # Settings form, theme picker, about card
│   ├── tutorials/
│   │   ├── providers/                 # TutorialsProvider (CRUD, filter, search)
│   │   └── screens/                   # Category filter, tutorial cards
│   ├── web_server/
│   │   ├── providers/                 # WebServerProvider (server lifecycle)
│   │   └── screens/                   # Server control, endpoints table, log view
│   └── whatsapp/
│       ├── providers/                 # WhatsAppProvider (number, message, history)
│       └── screens/                   # Phone input, country chips, launch actions
│
└── shared/
    └── widgets/
        ├── app_header.dart            # Top bar with logo, server status, theme toggle
        ├── responsive_sidebar.dart    # Left sidebar navigation (desktop/tablet)
        └── status_badge.dart          # Animated RUNNING / STOPPED badge
```

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `shadcn_ui` | ^0.57.0 | Shadcn-style UI components (Cards, Buttons, Inputs, Badges, Toasts, Alerts) |
| `lucide_icons_flutter` | ^3.1.20 | Lucide icon set |
| `provider` | ^6.1.5 | State management |
| `shelf` | ^1.4.2 | HTTP web server framework |
| `shelf_router` | ^1.1.4 | Route handler for Shelf |
| `shelf_static` | ^1.1.3 | Static file serving for Shelf |
| `shared_preferences` | ^2.5.5 | Persistent key-value storage |
| `url_launcher` | ^6.3.2 | Open URLs in browser/app |
| `file_picker` | ^13.1.0 | Native file picker dialog |
| `path_provider` | ^2.1.6 | Device file system paths |
| `http` | ^1.6.0 | HTTP client for API calls |
| `intl` | 0.20.2 | Date/number formatting |

---

## 🔨 Build & Release

### Android APK

```bash
# Debug APK
flutter build apk --debug

# Release APK (recommended for distribution)
flutter build apk --release

# Split per ABI (smaller downloads)
flutter build apk --release --split-per-abi
```

Release APK output: `build/app/outputs/flutter-apk/app-release.apk`

> **Windows cross-drive note:** If your Flutter pub cache is on `C:\` and your project is on another drive (e.g., `E:\`), you may encounter a Kotlin incremental cache error. This is pre-fixed in this repo via `kotlin.incremental=false` in `android/gradle.properties`.

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Windows Desktop

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/fdserver.exe`

### macOS

```bash
flutter build macos --release
```

### iOS

```bash
flutter build ipa --release
```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run unit tests only
flutter test test/unit_test.dart

# Run widget tests only
flutter test test/widget_test.dart

# Run with verbose output
flutter test --verbose

# Analyze code for issues
flutter analyze
```

### Test Coverage

| Test File | Coverage Area |
|-----------|---------------|
| `unit_test.dart` | WhatsApp URL builder, number cleaner, SocketMessage URL extractor, NoteItem/TutorialItem serialization round-trips, StorageService read/write |
| `widget_test.dart` | App launch + AppHeader rendering, sidebar navigation switching, Notes screen add/cancel dialog, WhatsApp screen inputs and country code chips |

---

## 🛡️ Permissions

### Android (`AndroidManifest.xml`)

| Permission | Reason |
|-----------|--------|
| `INTERNET` | Web server, WebSocket, URL launcher |
| `ACCESS_NETWORK_STATE` | Detect WiFi connectivity |
| `ACCESS_WIFI_STATE` | Read local IP address |
| `READ_EXTERNAL_STORAGE` | File picker (Android ≤ 12) |
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | File picker (Android 13+) |

### iOS (`Info.plist`)

| Key | Reason |
|----|--------|
| `NSLocalNetworkUsageDescription` | Local network server access |
| `NSPhotoLibraryUsageDescription` | File picker |

---

## 🔧 Troubleshooting

### Server won't start
- Check that the chosen port is not already occupied (`netstat -an | grep 8081`)
- Try a different port (e.g., `8080`, `9000`)
- On Android, ensure the `INTERNET` permission is granted

### Cannot access server from another device
- Both devices must be on the **same WiFi network**
- Check your device firewall isn't blocking the port
- Use the IP shown in the **Scanner → Local Network Interfaces** section, not `0.0.0.0`
- Try `http://{your-ip}:{port}/api/status` in a browser to verify

### Port scanner shows everything closed
- Some routers/firewalls block inter-device TCP probing — this is expected on corporate networks
- Try scanning `127.0.0.1` first with a running local service to verify the scanner works

### WhatsApp won't open
- Ensure WhatsApp is installed for the **Open WhatsApp** button
- Use **Open via Web (wa.me)** as a fallback — this works in any browser
- The phone number must be in full international format with no `+` or spaces (e.g., `919876543210`)

### Kotlin incremental build error (Windows)
- Symptom: `Could not close incremental caches in ...android_file_picker\kotlin\`
- Already fixed: `kotlin.incremental=false` is set in `android/gradle.properties`
- If it re-appears: run `flutter clean` then `flutter build apk --release`

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin feature/my-new-feature`
5. Submit a Pull Request

Please ensure `flutter analyze` reports zero issues and all tests pass before submitting.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ using Flutter · Shadcn UI · Dart
</p>
