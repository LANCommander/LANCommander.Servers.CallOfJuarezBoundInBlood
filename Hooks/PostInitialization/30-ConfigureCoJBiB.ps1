#Requires -Modules Logging

# Write the COJBIB_* settings into CoJ2\DedicatedServerSettings.ini (and an admin account into
# CoJ2\ServerAdmins.ini). The files are edited through the merged view, so the edited copies land
# in Overlay/CoJ2/. Set COJBIB_MANAGE_CONFIG=false to leave them alone and edit them yourself.
#
# Both files are Chrome Engine scripts: a block of `!Keyword(types)` declarations followed by
# `Keyword(args)` lines. The declarations are kept as they are; everything after them is rewritten.

$root     = $Env:SERVER_ROOT
$settings = Join-Path $root 'CoJ2/DedicatedServerSettings.ini'
$admins   = Join-Path $root 'CoJ2/ServerAdmins.ini'

if (-not (Test-Path -Path (Join-Path $root 'CoJ2Game_x86_ds.exe'))) {
    Write-Log -Level Error "CoJ2Game_x86_ds.exe not found in $root; skipping server configuration"
    return
}

if ($Env:COJBIB_MANAGE_CONFIG -match '^(0|false|no|off)$') {
    Write-Log "COJBIB_MANAGE_CONFIG is off; leaving CoJ2/DedicatedServerSettings.ini as it is"
    return
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

# Strings can't contain quotes; the parser has no escape for them
function ConvertTo-Quoted([string] $Value) {
    '"' + $Value.Replace('"', '') + '"'
}

# The declaration block: everything up to the last `!Keyword` line, plus the indented comment
# lines that continue its description. The stock "your settings start below" banner is dropped.
function Get-Header([string] $File) {
    $all  = [System.IO.File]::ReadAllLines($File)
    $last = -1
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($all[$i] -match '^\s*!') { $last = $i }
    }
    if ($last -lt 0) { return @() }
    while ($last + 1 -lt $all.Count -and $all[$last + 1] -match '^\s+//') { $last++ }
    $all[0..$last]
}

# Game modes. historical (Wild West Legends) has fixed limits.
$modeAliases = @{
    'deathmatch' = 'deathmatch'; 'shootout' = 'deathmatch'
    'teamdeathmatch' = 'teamdeathmatch'; 'posse' = 'teamdeathmatch'
    'wanted' = 'wanted'
    'teamwanted' = 'teamwanted'; 'manhunt' = 'teamwanted'
    'historical' = 'historical'; 'legends' = 'historical'; 'wildwestlegends' = 'historical'
}
$names = @{
    'deathmatch' = 'Shootout'; 'teamdeathmatch' = 'Posse'; 'wanted' = 'Wanted'
    'teamwanted' = 'Manhunt'; 'historical' = 'Wild West Legends'
}
# Stock limits from the installer's DedicatedServerSettings.ini
$stockBounty = @{ 'deathmatch' = 500; 'teamdeathmatch' = 1000; 'wanted' = 500 }
$stockPoints = 10
$stockTime   = 1200

$allMaps = 'Adobes', 'Civil', 'Coffeyville', 'Frisco', 'Magnificent', 'PrisonBreak2', 'StinkingSprings2', 'Tombstone'

$modeList = if ($Env:COJBIB_MODES) { $Env:COJBIB_MODES } else { 'deathmatch' }
$modes = foreach ($m in ($modeList -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $key = $m.ToLowerInvariant() -replace '[^a-z]', ''
    if (-not $modeAliases.ContainsKey($key)) {
        throw "Unknown game mode '$m' in COJBIB_MODES (use deathmatch, teamdeathmatch, wanted, teamwanted, historical)"
    }
    $modeAliases[$key]
}
$modes = @($modes | Select-Object -Unique)

$maps = if ($Env:COJBIB_MAPS) {
    @($Env:COJBIB_MAPS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object {
        $map = $_
        $stock = $allMaps | Where-Object { $_ -ieq $map } | Select-Object -First 1
        if ($stock) { $stock } else { $map }   # custom (user) maps are passed through
    })
} else {
    $allMaps
}

# ---- DedicatedServerSettings.ini ----
$header = if (Test-Path -Path $settings) { Get-Header $settings } else { @() }
if (-not ($header | Where-Object { $_ -match '^\s*!Map\(' })) {
    throw "CoJ2/DedicatedServerSettings.ini is missing its keyword declarations; restore it from Server/CoJ2/"
}

$name = if ($Env:COJBIB_SERVER_NAME) { $Env:COJBIB_SERVER_NAME } else { 'LANCommander CoJ BiB' }
if ($name -eq 'dedicated_server') {
    Write-Log -Level Warning "COJBIB_SERVER_NAME is the stock 'dedicated_server'; give the server a unique name"
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]] $header)
$lines.Add('/////////////////////////////////////////////////')
$lines.Add('// Written by LANCommander from the COJBIB_* environment variables on every start.')
$lines.Add('// Set COJBIB_MANAGE_CONFIG=false to edit this file yourself.')
$lines.Add('/////////////////////////////////////////////////')
$lines.Add('')
$lines.Add("ServerName($(ConvertTo-Quoted $name))")
$lines.Add("ServerPassword($(ConvertTo-Quoted $Env:COJBIB_SERVER_PASSWORD))")
$lines.Add("ServerPort($(if ($Env:COJBIB_PORT) { [int] $Env:COJBIB_PORT } else { 27632 }))")
$lines.Add("InternetServer($(ConvertTo-Flag $Env:COJBIB_INTERNET))")
$lines.Add("FriendlyFire($(ConvertTo-Flag $(if ($Env:COJBIB_FRIENDLY_FIRE) { $Env:COJBIB_FRIENDLY_FIRE } else { 'true' })))")
$lines.Add("PublicSlots($(if ($Env:COJBIB_MAX_PLAYERS) { [int] $Env:COJBIB_MAX_PLAYERS } else { 12 }))")
$lines.Add("PlayersToStart($(if ($Env:COJBIB_PLAYERS_TO_START) { [int] $Env:COJBIB_PLAYERS_TO_START } else { 1 }))")

foreach ($mode in $modes) {
    $lines.Add('')
    $lines.Add("// $($names[$mode])")

    if ($mode -eq 'teamwanted') {
        $points = if ($Env:COJBIB_POINTS_LIMIT) { [int] $Env:COJBIB_POINTS_LIMIT } else { $stockPoints }
        $lines.Add("PointsLimit(`"$mode`", $points)")
    } elseif ($mode -ne 'historical') {
        $bounty = if ($Env:COJBIB_BOUNTY_LIMIT) { [int] $Env:COJBIB_BOUNTY_LIMIT } else { $stockBounty[$mode] }
        $lines.Add("BountyLimit(`"$mode`", $bounty)")
    }

    if ($mode -ne 'historical') {
        $time = if ($Env:COJBIB_TIME_LIMIT) { [int] $Env:COJBIB_TIME_LIMIT } else { $stockTime }
        $lines.Add("TimeLimit(`"$mode`", $time)")
    }

    foreach ($map in $maps) {
        $lines.Add("Map($(ConvertTo-Quoted $map), `"$mode`")")
    }
}

[System.IO.File]::WriteAllText($settings, (($lines -join "`r`n") + "`r`n"))
chown "$($Env:UID):$($Env:GID)" $settings

Write-Log "Applied COJBIB_* settings to CoJ2/DedicatedServerSettings.ini: '$name', $($modes -join '/') on $($maps.Count) maps"

# ---- ServerAdmins.ini ----
if ($Env:COJBIB_ADMIN_LOGIN -and $Env:COJBIB_ADMIN_PASSWORD) {
    $header = if (Test-Path -Path $admins) { Get-Header $admins } else { @() }
    if (-not ($header | Where-Object { $_ -match '^\s*!Admin\(' })) { $header = @('!Admin( s, s, i )') }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]] $header)
    $lines.Add('')
    $lines.Add("Admin($(ConvertTo-Quoted $Env:COJBIB_ADMIN_LOGIN), $(ConvertTo-Quoted $Env:COJBIB_ADMIN_PASSWORD), 1)")

    [System.IO.File]::WriteAllText($admins, (($lines -join "`r`n") + "`r`n"))
    chown "$($Env:UID):$($Env:GID)" $admins

    Write-Log "Wrote admin account '$Env:COJBIB_ADMIN_LOGIN' to CoJ2/ServerAdmins.ini"
} elseif ($Env:COJBIB_ADMIN_LOGIN -or $Env:COJBIB_ADMIN_PASSWORD) {
    Write-Log -Level Warning "Set both COJBIB_ADMIN_LOGIN and COJBIB_ADMIN_PASSWORD to add an admin account"
}
