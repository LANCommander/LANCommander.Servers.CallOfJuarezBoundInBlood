---
sidebar_label: Docker
---

# Call of Juarez: Bound in Blood Docker Container

This Docker container runs a Call of Juarez: Bound in Blood dedicated server. It is built on the WINE image and runs Techland's official stand-alone server, `CoJ2Game_x86_ds.exe` (Dedicated Server 1.1.0.0), on a virtual display. The container doesn't download the server, so you provide its installer.

## Quick Start

```yaml
services:
  cojbib:
    image: lancommander/callofjuarezboundinblood:latest
    container_name: cojbib

    ports:
      - 27632:27632/udp

    volumes:
      - "/data/Servers/Call of Juarez - Bound in Blood/Deathmatch:/config"

    environment:
      COJBIB_SERVER_NAME: "My CoJ BiB Server"
      COJBIB_MODES: "deathmatch"
      COJBIB_ADMIN_LOGIN: "admin"
      COJBIB_ADMIN_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Before the first start, put `CoJ_BiB_DedicatedServer_setup.exe` (or the `CoJ_BiB_DedicatedServer_setup.zip` it often comes in) in the config directory. You can instead set `COJBIB_INSTALLER_URL`, or copy an installed server into `Server/`.

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitialization/20-InstallCoJBiB.ps1` checks for `Server/CoJ2Game_x86_ds.exe`. If it's missing, the hook finds the installer, unpacks its `app` files into `Server/` with `innoextract`, and extracts `d3dx9_39.dll` from the installer's `DirectX_redist/Aug2008_d3dx9_39_x86.cab` next to the exe. It drops the rest of the DirectX redist and remounts the overlay.
3. `PostInitialization/30-ConfigureCoJBiB.ps1` rewrites the settings in `CoJ2/DedicatedServerSettings.ini` from the `COJBIB_*` variables, and writes the admin account into `CoJ2/ServerAdmins.ini` if one is set.
4. `START_EXE` (`/usr/local/bin/cojbib-server`) runs `CoJ2Game_x86_ds.exe [START_ARGS]` from the server folder under Wine and Xvfb, with `d3dx9_39=n,b`. The server has no console output. It writes its log to `CoJ2/out/logs/crash.log`, which the launcher follows into `docker logs`, minus the missing client asset warnings it prints on every map load.

A healthy start ends with:

```
Dedicated server <My CoJ BiB Server> running
Loading server settings
[ITools::CreateServer] Bound to <10.0.1.50:27632>
[CServer::SetServerState] state set to : Playing map   with map:  Adobes.exp, with map num:  7
```

## Configuration Options

### Ports

- **27632/udp**: Game (`COJBIB_PORT`)

The server only binds the game port (plus a random local port). The readme also lists 32500, but that's an outgoing connection to Techland's master server (`mpl.techland.pl`), which is offline. The engine's All-Seeing Eye query port setting (`AllSeeingEyePort` in `CoJ2/Data/Network.scr`, game port + 1) isn't bound by the dedicated server.

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### DedicatedServerSettings.ini

The file is a Chrome Engine script, not an INI. A block of `!Keyword(types)` declarations, which must stay, is followed by `Keyword(args)` lines. The hook keeps the declarations and rewrites everything after them. It edits the file through the merged view, so the edited copy is in `Overlay/CoJ2/`. With `COJBIB_MANAGE_CONFIG=false` the hook leaves it alone, and the copy in `Overlay/` (or the stock one from `Server/`) is used as it is.

| Keyword | Meaning |
|---------|---------|
| `ServerName(s)` | Name in the server list. Must be unique |
| `ServerPassword(s)` | Registers the name with the master server; not a join password |
| `ServerPort(i)` | Game port |
| `InternetServer(i)` | `1` internet (master server), `0` LAN |
| `PublicSlots(i)` | Max players (12 by default) |
| `PlayersToStart(i)` | Players needed before a round begins |
| `FriendlyFire(i)` | `1` on, `0` off |
| `Map(s, s)` | One rotation entry: map, mode. Played in file order |
| `PointsLimitDefault(i)`, `BountyLimitDefault(i)`, `TimeLimitDefault(i)` | Limits for all modes |
| `PointsLimit(s, i)`, `BountyLimit(s, i)`, `TimeLimit(s, i)` | Limits for one mode, after the defaults. Time is in seconds |

Modes: `deathmatch` (Shootout), `teamdeathmatch` (Posse), `wanted` (Wanted), `teamwanted` (Manhunt), `historical` (Wild West Legends, fixed limits). `PointsLimit` is for Manhunt only; `BountyLimit` is for Shootout, Posse and Wanted.

### Admin Commands

`COJBIB_ADMIN_LOGIN`/`COJBIB_ADMIN_PASSWORD` add `Admin("<login>", "<password>", 1)` (full rights) to `CoJ2/ServerAdmins.ini`. If the variables are later removed, the file keeps the last account. Admins log in from the in-game chat:

```
/AdminLogin <login> <password>
/AdminSay <text>
/MapNext
/PlayerList
/Kick <name or id>
/Kill <name>
/AdminLogout
```

The server's own console window exists only on the virtual display, so it can't be used.

### User Maps

Install a user map's files in the server folder through `Overlay/` (the same layout as on a client), then name it in `COJBIB_MAPS`. Names that aren't stock maps are passed through unchanged. User maps are untested with this image. Clients need the same map, in the same version.

### Hooks

| Hook | When |
|------|------|
| `PreInstallCoJBiB` / `PostInstallCoJBiB` | Around the installer check/unpack |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **`CoJ2Game_x86_ds.exe not found` and the container exits**: there's no installer in `/config`. The file name must be `CoJ_BiB_DedicatedServer_setup.exe` or `.zip`; otherwise set `COJBIB_INSTALLER`.
- **Exits immediately without a display**: the server is a GUI program. Keep `WINE_XVFB=true`.
- **The game client's `-dedicated`/`-server` switches**: `CoJBiBGame_x86.exe` has them, but under Wine `-dedicated` only plays the intro and quits, and `-dedicated -server` crashes in `engine_x86.dll` after creating its D3D device. Use the official dedicated server.
- **`Bound to <172.x.x.x:27632>` on the wrong address**: the server binds the address its hostname resolves to. On a bridge network that's the container address, which is fine with port publishing. To force another address, put a `CoJ2/Data/Network.scr` with `ForceNetworkInterface("a.b.c.d")` in `Overlay/`.
- **The map never changes**: with no players, the round clock doesn't run (`PlayersToStart`).
- **Not in the in-game server list**: LAN discovery is untested with this image. Discovery by broadcast needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`). The internet list used Techland's master server, which is offline.
- **Clients can't connect**: client and server must both be version 1.1.0.0, and the client needs every map in the rotation.
