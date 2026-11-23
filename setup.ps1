# HMaps - bo cai cho MicroStation V8i. Chay qua setup.cmd (ban nguon) hoac HMaps-Setup.cmd (ban cong khai).
#  - Co thu muc src ben canh: bien dich tai may roi cai.
#  - Khong co: tai HMaps.dll da bien dich tu kho cong khai roi cai.
# Thong bao viet khong dau de khong loi font tren cua so lenh.
param(
    [string]$MsDir = "",
    [string]$Repo = "luantvu/HMaps-Public",
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]3072
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
$Inst = Join-Path $env:LOCALAPPDATA 'HMaps'
$Raw  = "https://raw.githubusercontent.com/$Repo/main"
$DevMode = Test-Path (Join-Path $Root 'src\Addin')

function Find-MicroStation {
    if ($MsDir -and (Test-Path (Join-Path $MsDir 'ustation.dll'))) { return $MsDir }
    $cands = @()
    foreach ($pf in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not $pf) { continue }
        $cands += Join-Path $pf 'Bentley\MicroStation V8i (SELECTseries)\MicroStation'
        $cands += Join-Path $pf 'Bentley\MicroStation V8i\MicroStation'
        $cands += Join-Path $pf 'Bentley\MicroStation'
    }
    $p = Get-Process ustation -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p -and $p.Path) { $cands = @(Split-Path -Parent $p.Path) + $cands }
    foreach ($c in $cands) { if (Test-Path (Join-Path $c 'ustation.dll')) { return $c } }
    Write-Host "Khong tu tim thay MicroStation V8i."
    $d = Read-Host "Nhap duong dan thu muc chua ustation.exe"
    $d = $d.Trim('"', ' ')
    if (Test-Path (Join-Path $d 'ustation.dll')) { return $d }
    throw "Thu muc '$d' khong co ustation.dll"
}

function Build-Addin($ms) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v3.5\csc.exe'
    if (-not (Test-Path $csc)) { throw "Khong thay $csc. Hay bat .NET Framework 3.5 trong 'Turn Windows features on or off'." }
    $refs = @()
    $refDir = Join-Path $Root 'refs'
    New-Item -ItemType Directory -Force $refDir | Out-Null
    $need = @{ 'ustation.dll' = $true; 'Bentley.MicroStation.dll' = $true; 'Bentley.Interop.MicroStationDGN.dll' = $true;
               'Bentley.MicroStation.Interfaces.1.0.dll' = $false; 'Bentley.General.1.0.dll' = $false }
    foreach ($n in $need.Keys) {
        $f = Get-ChildItem -LiteralPath $ms -Recurse -Filter $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) {
            Write-Host "  tham chieu: $($f.FullName)"
            $refs += "/r:$($f.FullName)"
            Copy-Item -LiteralPath $f.FullName -Destination $refDir -Force
        }
        elseif ($need[$n]) { throw "Khong tim thay $n trong $ms" }
        else { Write-Host "  (khong co $n - bo qua)" }
    }
    $bin = Join-Path $Root 'bin'
    New-Item -ItemType Directory -Force $bin | Out-Null
    $out = Join-Path $bin 'HMaps.dll'
    $cscArgs = @('/nologo', '/target:library', '/platform:x86', '/codepage:65001', '/optimize+', '/warn:3',
        "/out:$out", "/resource:$Root\src\Addin\commands.xml,HMaps.commands.xml",
        '/r:System.dll', '/r:System.Core.dll', '/r:System.Data.dll', '/r:System.Xml.dll',
        '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll') + $refs + @("/recurse:$Root\src\*.cs")
    $log = & $csc @cscArgs 2>&1
    $log | Out-File (Join-Path $Root 'build.log') -Encoding utf8
    $log | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Bien dich that bai. Xem build.log" }
    return $out
}

function Swap-In($src, $dst) {
    # DLL dang duoc MicroStation nap thi khong ghi de duoc nhung doi ten duoc.
    if (Test-Path $dst) {
        $old = "$dst.old"
        Remove-Item $old -Force -ErrorAction SilentlyContinue
        if (Test-Path $old) { $old = "$dst.old." + [DateTime]::Now.Ticks }
        Rename-Item $dst $old
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

function Write-Cfg($ms) {
    $cfg = Join-Path $ms 'config\appl\HMaps.cfg'
    $dir = ($Inst -replace '\\', '/') + '/'
    $text = "# HMaps: tu nap Add-in khi mo ban ve. Xoa file nay de tat.`r`nMS_ADDINPATH < $dir`r`nMS_DGNAPPS > HMaps`r`n"
    $tmp = Join-Path $env:TEMP 'HMaps.cfg'
    [IO.File]::WriteAllText($tmp, $text, [Text.Encoding]::ASCII)
    try { Copy-Item $tmp $cfg -Force; return $true } catch { }
    Write-Host "Can quyen Administrator de ghi cau hinh vao thu muc MicroStation - hay bam Yes o hop thoai sap hien."
    try {
        Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "/c copy /y `"$tmp`" `"$cfg`""
    } catch { }
    return (Test-Path $cfg)
}

try {
    Write-Host "=== HMaps cho MicroStation V8i ==="
    $ms = Find-MicroStation
    Write-Host "MicroStation: $ms"

    if ($Uninstall) {
        $cfg = Join-Path $ms 'config\appl\HMaps.cfg'
        if (Test-Path $cfg) {
            try { Remove-Item $cfg -Force } catch {
                Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "/c del `"$cfg`""
            }
        }
        Write-Host "Da go cau hinh tu nap. Dong MicroStation roi xoa thu muc $Inst de go han."
        return
    }

    $stage = Join-Path $env:TEMP ('HMaps-stage-' + [DateTime]::Now.Ticks)
    New-Item -ItemType Directory -Force $stage | Out-Null
    if ($DevMode) {
        Write-Host "Che do ma nguon: bien dich tai may..."
        $dll = Build-Addin $ms
        Copy-Item $dll (Join-Path $stage 'HMaps.dll')
        Copy-Item (Join-Path $Here 'update.ps1') $stage
        $v = (Get-Content (Join-Path $Root 'version.json') -Raw | ConvertFrom-Json).version
    }
    else {
        Write-Host "Tai ban moi nhat tu github.com/$Repo ..."
        $wc = New-Object Net.WebClient
        $info = $wc.DownloadString("$Raw/version.json") | ConvertFrom-Json
        $wc.DownloadFile("$Raw/HMaps.dll", (Join-Path $stage 'HMaps.dll'))
        $wc.DownloadFile("$Raw/update.ps1", (Join-Path $stage 'update.ps1'))
        $v = $info.version
        $h = (Get-FileHash (Join-Path $stage 'HMaps.dll') -Algorithm SHA256).Hash
        if ($h -ne $info.sha256.ToUpper()) { throw "File tai ve sai ma kiem tra SHA256. Thu lai sau vai phut." }
    }

    New-Item -ItemType Directory -Force $Inst | Out-Null
    Swap-In (Join-Path $stage 'HMaps.dll') (Join-Path $Inst 'HMaps.dll')
    Copy-Item (Join-Path $stage 'update.ps1') $Inst -Force
    $h = (Get-FileHash (Join-Path $Inst 'HMaps.dll') -Algorithm SHA256).Hash
    [IO.File]::WriteAllText((Join-Path $Inst 'version.json'), "{ `"version`": `"$v`", `"sha256`": `"$h`" }")
    [IO.File]::WriteAllText((Join-Path $Inst 'repo.txt'), $Repo)
    Write-Host "Da cai HMaps $v vao $Inst"

    if (Write-Cfg $ms) {
        Write-Host ""
        Write-Host "[XONG] Mo lai MicroStation: HMaps tu nap. Go key-in:  hmaps info"
    }
    else {
        Write-Host ""
        Write-Host "[XONG MOT PHAN] Chua ghi duoc cau hinh tu nap. Trong MicroStation go key-in:"
        Write-Host "    mdl load `"$Inst\HMaps.dll`""
    }
    if ($DevMode) {
        Write-Host ""
        Write-Host "Ghi chu: 5 file DLL tham chieu cua Bentley da duoc chep vao thu muc refs\."
    }
}
catch {
    Write-Host ""
    Write-Host "[THAT BAI] $($_.Exception.Message)"
    Write-Host "Hay gui lai noi dung cua so nay (va build.log neu co)."
    exit 1
}
