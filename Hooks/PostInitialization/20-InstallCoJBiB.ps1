#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# The Call of Juarez: Bound in Blood Dedicated Server 1.1.0.0 can't be redistributed. Use an
# installed copy in /config/Server, or unpack Techland's CoJ_BiB_DedicatedServer_setup.exe (an Inno
# Setup installer, optionally inside a zip) from COJBIB_INSTALLER, /config, or COJBIB_INSTALLER_URL.

Invoke-Hook "PreInstallCoJBiB"

$exe = Join-Path $Env:SERVER_DIR 'CoJ2Game_x86_ds.exe'

function Find-Installer {
    if ($Env:COJBIB_INSTALLER) {
        if (-not (Test-Path -Path $Env:COJBIB_INSTALLER)) { throw "COJBIB_INSTALLER not found: $Env:COJBIB_INSTALLER" }
        return $Env:COJBIB_INSTALLER
    }

    if ($Env:COJBIB_INSTALLER_URL) {
        $name = [System.IO.Path]::GetFileName(([uri]$Env:COJBIB_INSTALLER_URL).AbsolutePath)
        if ($name -notmatch '\.(exe|zip)$') { $name = 'CoJ_BiB_DedicatedServer_setup.exe' }
        $file = Join-Path '/tmp' $name

        Write-Log "Downloading the dedicated server installer from $Env:COJBIB_INSTALLER_URL"
        curl -fL --retry 3 --output $file "$Env:COJBIB_INSTALLER_URL"
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:COJBIB_INSTALLER_URL" }
        return $file
    }

    Get-ChildItem -Path '/config' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^CoJ_BiB_DedicatedServer_setup\.(exe|zip)$' } |
        Sort-Object Extension |
        Select-Object -First 1 -ExpandProperty FullName
}

if (Test-Path -Path $exe) {
    Write-Log "Call of Juarez: Bound in Blood Dedicated Server found in $Env:SERVER_DIR"
} else {
    $installer = Find-Installer

    if (-not $installer) {
        Write-Log -Level Error "CoJ2Game_x86_ds.exe not found in $Env:SERVER_DIR. Put CoJ_BiB_DedicatedServer_setup.exe (or its zip) in /config, or set COJBIB_INSTALLER / COJBIB_INSTALLER_URL."
    } else {
        $work = '/tmp/cojbib'
        Remove-Item -Recurse -Force -Path $work -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $work -Force | Out-Null

        if ($installer -match '\.zip$') {
            Write-Log "Extracting $installer"
            unzip -q -o $installer -d "$work/zip"
            if ($LASTEXITCODE -ne 0) { throw "Could not extract $installer" }

            $installer = Get-ChildItem -Path "$work/zip" -Filter '*.exe' -Recurse -File |
                Select-Object -First 1 -ExpandProperty FullName
            if (-not $installer) { throw "No installer .exe in the zip" }
        }

        Write-Log "Unpacking $installer"
        innoextract --silent --extract --output-dir "$work/out" $installer
        if ($LASTEXITCODE -ne 0) { throw "innoextract failed on $installer" }

        $app = Join-Path $work 'out/app'
        if (-not (Test-Path -Path (Join-Path $app 'CoJ2Game_x86_ds.exe'))) {
            throw "CoJ2Game_x86_ds.exe not found in $installer; is it CoJ_BiB_DedicatedServer_setup.exe?"
        }

        # The server imports d3dx9_39.dll. Use Microsoft's from the installer's own DirectX redist
        # rather than Wine's builtin (the game client crashes compiling shaders with the builtin).
        $cab = Join-Path $app 'DirectX_redist/Aug2008_d3dx9_39_x86.cab'
        if (Test-Path -Path $cab) {
            cabextract -q -F d3dx9_39.dll -d $app $cab
            if ($LASTEXITCODE -ne 0) { throw "Could not extract d3dx9_39.dll from $cab" }
        } else {
            Write-Log -Level Warning "Aug2008_d3dx9_39_x86.cab not in the installer; using Wine's builtin d3dx9_39"
        }
        Remove-Item -Recurse -Force -Path (Join-Path $app 'DirectX_redist')

        New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
        Move-Item -Force -Path (Join-Path $app '*') -Destination $Env:SERVER_DIR
        chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

        Remove-Item -Recurse -Force -Path $work
        if ($Env:COJBIB_INSTALLER_URL -and -not $Env:COJBIB_INSTALLER) {
            Remove-Item -Force -Path $installer -ErrorAction SilentlyContinue
        }

        # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
        # lower-dir changes made while mounted.
        mountpoint -q $Env:SERVER_ROOT
        if ($LASTEXITCODE -eq 0) {
            umount $Env:SERVER_ROOT
            Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
            Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
            Write-Log "OverlayFS remounted"
        }

        Write-Log "Call of Juarez: Bound in Blood Dedicated Server installed"
    }
}

Invoke-Hook "PostInstallCoJBiB"

Set-Location $Env:SERVER_ROOT
