# Call of Juarez: Bound in Blood Server (Docker)

This repository provides a Dockerized **Call of Juarez: Bound in Blood** dedicated server. Techland released a Windows-only stand-alone server for the game in 2009, the *Call of Juarez: Bound in Blood Dedicated Server 1.1.0.0* (`CoJ2Game_x86_ds.exe`). The image runs it under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Unpacks Techland's official installer (`CoJ_BiB_DedicatedServer_setup.exe`) on first start, without running it
- Server name, port, game modes, map rotation, limits and an admin account are environment variables, written into `CoJ2\DedicatedServerSettings.ini` and `CoJ2\ServerAdmins.ini` on every start
- All five game modes: Shootout, Posse, Wanted, Manhunt and Wild West Legends, on the eight stock maps or user maps
- The server's log is followed to `docker logs`
- The server is a GUI program, so it runs on a virtual display (Xvfb)
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  cojbib:
    image: lancommander/callofjuarezboundinblood:latest
    container_name: cojbib

    ports:
      - "27632:27632/udp"

    volumes:
      - ./config:/config

    environment:
      COJBIB_SERVER_NAME: "My CoJ BiB Server"
      COJBIB_MODES: "deathmatch,teamdeathmatch"
      COJBIB_ADMIN_LOGIN: "admin"
      COJBIB_ADMIN_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

The dedicated server can't be redistributed, so the image doesn't download it. Get `CoJ_BiB_DedicatedServer_setup.exe` (396 MB, Inno Setup, often distributed as `CoJ_BiB_DedicatedServer_setup.zip`), e.g. from [ModDB](https://www.moddb.com/games/call-of-juarez-bound-in-blood/downloads/pc-dedicated-server), and:

- put the `.exe` or the `.zip` in `config/`, **or**
- set `COJBIB_INSTALLER` to its path inside the container, **or**
- set `COJBIB_INSTALLER_URL` to a download URL, **or**
- copy an installed server (the folder containing `CoJ2Game_x86_ds.exe`) to `config/Server/`.

On first start, if `Server/CoJ2Game_x86_ds.exe` doesn't exist, the install hook unpacks the installer with `innoextract` into `Server/`. It also takes `d3dx9_39.dll` from the installer's own DirectX redist and drops the rest of the redist. The server is self-contained and doesn't need the game installed. It is version 1.1.0.0, so clients need the 1.1.0.0 patch, which the GOG and Steam releases include.

## Directory Layout (Host)

```text
.
└── config/
    ├── CoJ_BiB_DedicatedServer_setup.zip   # The installer (only needed until Server/ exists)
    ├── Server/            # Unpacked dedicated server (CoJ2Game_x86_ds.exe, CoJ2/*.pak ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated
    │                      # CoJ2/DedicatedServerSettings.ini and ServerAdmins.ini, CoJ2/out/ logs)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
On every start the configure hook rewrites the settings part of `CoJ2\DedicatedServerSettings.ini` from the `COJBIB_*` variables. It keeps the file's keyword declarations. Set `COJBIB_MANAGE_CONFIG=false` to edit the file yourself instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `COJBIB_SERVER_NAME` | `ServerName`, shown in the server list. Techland's readme says to replace the stock `dedicated_server` with a unique name | `LANCommander CoJ BiB` |
| `COJBIB_SERVER_PASSWORD` | `ServerPassword`. This registers the server name with the master server; it is **not** a join password (the server has none) | |
| `COJBIB_PORT` | Game port (`ServerPort`) | `27632` |
| `COJBIB_INTERNET` | `InternetServer`: `true` lists the server on Techland's master server, which is offline; `false` makes a LAN server | `false` |
| `COJBIB_MAX_PLAYERS` | `PublicSlots` | `12` |
| `COJBIB_PLAYERS_TO_START` | `PlayersToStart`, the players needed before a round begins | `1` |
| `COJBIB_FRIENDLY_FIRE` | `FriendlyFire` | `true` |
| `COJBIB_MODES` | Comma-separated game modes, played in this order: `deathmatch` (Shootout), `teamdeathmatch` (Posse), `wanted`, `teamwanted` (Manhunt), `historical` (Wild West Legends). The in-game names (`shootout`, `posse`, `manhunt`, `legends`) work too | `deathmatch` |
| `COJBIB_MAPS` | Comma-separated maps, played in every mode. Empty = all eight stock maps. Names that aren't stock maps are passed through as user maps | |
| `COJBIB_TIME_LIMIT` | Map time limit in **seconds** (`TimeLimit`, not used by Wild West Legends) | `1200` |
| `COJBIB_BOUNTY_LIMIT` | Bounty to win (`BountyLimit`, Shootout, Posse and Wanted) | `500` (Posse `1000`) |
| `COJBIB_POINTS_LIMIT` | Points to win (`PointsLimit`, Manhunt) | `10` |
| `COJBIB_ADMIN_LOGIN` | Admin login written to `CoJ2\ServerAdmins.ini` with full rights. Needs `COJBIB_ADMIN_PASSWORD` | |
| `COJBIB_ADMIN_PASSWORD` | Admin password | |
| `COJBIB_MANAGE_CONFIG` | `false` = don't touch `DedicatedServerSettings.ini` or `ServerAdmins.ini` | `true` |
| `COJBIB_INSTALLER` | Path of the installer `.exe` or `.zip` in the container. Empty = look for `CoJ_BiB_DedicatedServer_setup.exe`/`.zip` in `/config` | |
| `COJBIB_INSTALLER_URL` | Download URL of the installer `.exe` or `.zip`, used if `Server/CoJ2Game_x86_ds.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. The server exits without one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/cojbib-server` |
| `START_ARGS` | Added to the `CoJ2Game_x86_ds.exe` command line | |

Stock maps (`COJBIB_MAPS` name, in-game name): `Adobes` (Taos Pueblo), `Civil` (Burnside's Bridge), `Coffeyville`, `Frisco`, `Magnificent`, `PrisonBreak2` (Nogales), `StinkingSprings2` (Stinking Springs), `Tombstone`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/callofjuarezboundinblood:local .
```

---

## License

Call of Juarez: Bound in Blood, its dedicated server and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
