# HMaps - tu cap nhat tu kho GitHub cong khai. Add-in goi file nay o che do an moi ngay mot lan;
# key-in "hmaps update" goi voi -Interactive.
param([switch]$Interactive)
$ErrorActionPreference = 'Stop'
$Inst = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $Inst 'update.log'
function Say($m) {
    try { Add-Content $LogFile ((Get-Date -Format s) + ' ' + $m) } catch { }
    if ($Interactive) { Write-Host $m }
}
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]3072
    Set-Content (Join-Path $Inst 'last-check.txt') (Get-Date -Format s)
    $repo = (Get-Content (Join-Path $Inst 'repo.txt') -TotalCount 1).Trim()
    $raw = "https://raw.githubusercontent.com/$repo/main"
    $wc = New-Object Net.WebClient
    $remote = $wc.DownloadString("$raw/version.json?t=" + [DateTime]::UtcNow.Ticks) | ConvertFrom-Json

    # Menu "HMaps" tren thanh menu (HMaps.dgnlib): cai/cap nhat neu ghi duoc thu muc WorkSpace (khong can admin).
    if ($remote.menu) {
        $ws = Join-Path $env:ProgramData 'Bentley\MicroStation V8i (SELECTseries)\WorkSpace\Interfaces\MicroStation\default'
        $lib = Join-Path $ws 'HMaps.dgnlib'
        $cur = ''; if (Test-Path $lib) { $cur = (Get-FileHash $lib -Algorithm SHA256).Hash }
        if ((Test-Path (Split-Path -Parent $ws)) -and $cur -ne $remote.menu.ToUpper()) {
            try {
                $tmp = Join-Path $Inst 'HMaps.dgnlib.new'
                $wc.DownloadFile("$raw/HMaps.dgnlib", $tmp)
                if ((Get-FileHash $tmp -Algorithm SHA256).Hash -eq $remote.menu.ToUpper()) {
                    New-Item -ItemType Directory -Force $ws | Out-Null
                    Copy-Item $tmp $lib -Force
                    Say "Da cai menu HMaps: $lib"
                }
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
            catch { Say "Chua cai duoc menu HMaps (chay lai bo cai): $($_.Exception.Message)" }
        }
    }

    $local = '0.0.0'
    $vf = Join-Path $Inst 'version.json'
    if (Test-Path $vf) { $local = (Get-Content $vf -Raw | ConvertFrom-Json).version }
    if ([version]$remote.version -le [version]$local) { Say "Dang dung ban moi nhat ($local)."; return }

    Say "Co ban moi $($remote.version) (dang dung $local). Dang tai..."
    $dll = Join-Path $Inst 'HMaps.dll'
    $new = "$dll.new"
    $wc.DownloadFile("$raw/HMaps.dll", $new)
    $hash = (Get-FileHash $new -Algorithm SHA256).Hash
    if ($hash -ne $remote.sha256.ToUpper()) { Remove-Item $new -Force; throw "File tai ve sai ma kiem tra SHA256." }

    # DLL dang nap khong ghi de duoc nhung doi ten duoc; ban moi co hieu luc khi mo lai MicroStation.
    Get-ChildItem $Inst -Filter 'HMaps.dll.old*' | Remove-Item -Force -ErrorAction SilentlyContinue
    if (Test-Path $dll) {
        $old = "$dll.old"
        if (Test-Path $old) { $old = "$dll.old." + [DateTime]::Now.Ticks }
        Rename-Item $dll $old
    }
    Rename-Item $new $dll
    [IO.File]::WriteAllText($vf, "{ `"version`": `"$($remote.version)`", `"sha256`": `"$hash`" }")
    Set-Content (Join-Path $Inst 'updated.txt') $remote.version
    Say "Da cap nhat len $($remote.version). Mo lai MicroStation de dung ban moi."
}
catch { Say "LOI cap nhat: $($_.Exception.Message)" }
finally { if ($Interactive) { Read-Host 'Nhan Enter de dong' | Out-Null } }
