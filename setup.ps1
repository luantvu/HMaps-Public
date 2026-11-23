# HMaps - bo cai cho MicroStation V8i. Chay qua setup.cmd (ban nguon) hoac HMaps-Setup.cmd (ban cong khai).
#  - Co thu muc src ben canh: bien dich tai may roi cai.
#  - Khong co: tai HMaps.dll da bien dich tu kho cong khai roi cai.
# Thong bao viet khong dau de khong loi font tren cua so lenh.
param(
    [string]$MsDir = "",
    [string]$Repo = "luantvu/HMaps-Public",
    [string]$InstDir = "",      # thu muc cai; bo cai .exe truyen C:\ProgramData\HMaps
    [string]$Dll = "",          # HMaps.dll da bien dich san (bo cai .exe ban phat hanh)
    [switch]$Quiet,             # khong hoi gi (chay tu bo cai .exe)
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]3072
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
$Inst = Join-Path $env:LOCALAPPDATA 'HMaps'
if ($InstDir) { $Inst = $InstDir }
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
    if ($Quiet) { throw "Khong tim thay MicroStation V8i (ustation.dll)." }
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
    # commands.xml hong thi MicroStation van bao "loaded" nhung khong co key-in nao: kiem tra truoc.
    $xmlPath = Join-Path $Root 'src\Addin\commands.xml'
    try { [xml](Get-Content $xmlPath -Raw -Encoding UTF8) | Out-Null }
    catch { throw "commands.xml khong hop le: $($_.Exception.Message)" }
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

# Cach du phong (khi khong ghi duoc config\appl): tao User "HMaps" trong WorkSpace\Users
# (chon o o User cua hop thoai File Open), MS_INIT chay StartUpHMaps.UCM -> mdl load HMaps.dll.
$UserName = 'HMaps'

function Get-WorkspaceRoot($ms) {
    $ini = Join-Path $ms 'config\msdir.cfg'
    if (Test-Path $ini) {
        foreach ($l in Get-Content $ini) {
            if ($l -match '^\s*_USTN_INSTALLED_WORKSPACEROOT\s*=\s*(.+?)\s*$') {
                $p = ($Matches[1] -replace '[\\/]+', '\').TrimEnd('\')
                if (Test-Path $p) { return $p }
            }
        }
    }
    foreach ($c in @((Join-Path $env:ProgramData 'Bentley\MicroStation V8i (SELECTseries)\WorkSpace'),
                     (Join-Path $ms '..\WorkSpace'))) {
        if (Test-Path (Join-Path $c 'Users')) { return (Resolve-Path $c).Path }
    }
    throw "Khong tim thay thu muc WorkSpace cua MicroStation."
}

# Ghi file; neu khong du quyen thi nho cmd chay quyen Administrator chep vao.
function Put-File($text, $dst) {
    $tmp = Join-Path $env:TEMP ('HMaps-' + [IO.Path]::GetFileName($dst))
    [IO.File]::WriteAllText($tmp, $text, [Text.Encoding]::ASCII)
    try { New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null; Copy-Item $tmp $dst -Force; return $true } catch { }
    Write-Host "Can quyen Administrator de ghi $dst - hay bam Yes o hop thoai sap hien."
    try { Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "/c copy /y `"$tmp`" `"$dst`"" } catch { }
    return (Test-Path $dst)
}

function Remove-AsAdmin($path) {
    if (-not (Test-Path $path)) { return }
    try { Remove-Item $path -Force } catch {
        try { Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "/c del /f `"$path`"" } catch { }
    }
}

# Thu muc prefs cua MicroStation V8i cho nguoi dung hien tai (co the co nhieu ban cai).
function Get-PrefsDirs {
    $base = Join-Path $env:LOCALAPPDATA 'Bentley\MicroStation\8.11'
    if (-not (Test-Path $base)) { return @() }
    return @(Get-ChildItem $base -Directory | ForEach-Object { Join-Path $_.FullName 'prefs' } | Where-Object { Test-Path $_ })
}

# User (profile) HMaps: chon o o User cua hop thoai File Open, hoac mo tu shortcut "HMaps" (-wuHMaps).
# O User nay HMaps mo giao dien rieng (thanh lenh tieng Viet dock phia tren), giong LandMapV8i.
# $withInit: cach du phong khi khong ghi duoc config\appl - nap HMaps bang MS_INIT/UCM va dat lam User mac dinh.
function Write-Profile($ms, $withInit) {
    $ws = Get-WorkspaceRoot $ms
    $ucf = Join-Path $ws "Users\$UserName.ucf"
    $ucm = Join-Path $ws "System\ucm\StartUp$UserName.UCM"
    $dll = Join-Path $Inst 'HMaps.dll'
    $text = "#  HMaps - tao boi bo cai HMaps. User (profile) rieng cua HMaps: mo giao dien HMaps.`r`n" +
            "_USTN_USERDESCR     = HMaps Workspace`r`n" +
            "_USTN_PROJECTNAME   = untitled`r`n`r`n" +
            "%if defined (_NAVIGATOR)`r`n_USTN_USERINTNAME = default`r`n%endif`r`n" +
            "MS_PROTECTION_ENABLE = 1`r`n`r`n"
    if ($withInit) {
        $text += "MS_INIT = StartUp$UserName.UCM`r`n" +
                 "MS_UCM = `$(_USTN_SYSTEMROOT)ucm/`r`n`r`n" +
                 "MS_ADDINPATH > $Inst`r`n"
    }
    $ok = Put-File $text $ucf
    if ($withInit) { $ok = (Put-File "key 'mdl load $dll'`r`n" $ucm) -and $ok }
    else { Remove-AsAdmin $ucm }   # ban cu: HMaps da tu nap qua config\appl, UCM se nap lan 2
    if ($ok) { Write-Host "User (profile) '$UserName': $ucf" }

    foreach ($p in Get-PrefsDirs) {
        # User moi chua co file .upf thi MicroStation V8i bi loi accudraw (System fault 99) khi mo lan dau:
        # lay file prefs cua User 'untitled' lam goc.
        $upf = Join-Path $p "$UserName.upf"
        $seed = Join-Path $p 'untitled.upf'
        if (-not (Test-Path $upf) -and (Test-Path $seed)) { Copy-Item $seed $upf }
        if (-not $withInit) { continue }
        # Dat HMaps lam User mac dinh, nho User cu de go cai thi tra lai.
        $dflt = Join-Path $p 'dfltuser.cfg'
        $prev = ''
        if (Test-Path $dflt) {
            $m = Select-String -Path $dflt -Pattern '^\s*_USTN_USERNAME\s*=\s*(\S+)' | Select-Object -First 1
            if ($m) { $prev = $m.Matches[0].Groups[1].Value }
        }
        if ($prev -ne $UserName) {
            if ($prev) { [IO.File]::WriteAllText((Join-Path $p 'HMaps-prev-user.txt'), $prev) }
            [IO.File]::WriteAllText($dflt, "_USTN_USERNAME = $UserName`r`n", [Text.Encoding]::ASCII)
            Write-Host "User mac dinh: $UserName (truoc do: $(if ($prev) { $prev } else { 'chua dat' }))"
        }
    }
    return $ok
}

# Tu nap cho MOI User (khong phai chon User HMaps): config\appl\HMaps.cfg nap HMaps qua MS_DGNAPPS.
# Can MS_ADDINPATH tro toi thu muc cai thi MDL loader moi tim thay add-in .NET (thieu no se bao
# "Could not load application HMaps"). Menu "HMaps" tren thanh menu: HMaps.dgnlib dat trong
# WorkSpace\Interfaces\MicroStation\default (giong gCadas, LandMap) nen hien voi moi User.
function Get-ApplCfgPath($ms) { return (Join-Path $ms 'config\appl\HMaps.cfg') }
function Get-MenuLibPath($ms) { return (Join-Path (Get-WorkspaceRoot $ms) 'Interfaces\MicroStation\default\HMaps.dgnlib') }

function Write-Autoload($ms, $menuLib) {
    $dir = $Inst.TrimEnd('\')
    $local = $env:LOCALAPPDATA.TrimEnd('\')
    if ($dir -like "$local\*") { $dir = '$(LOCALAPPDATA)' + $dir.Substring($local.Length) }   # dung cho moi tai khoan Windows
    $dir = ($dir -replace '\\', '/') + '/'
    $text = "#  HMaps - tao boi bo cai HMaps: tu nap HMaps voi moi User cua MicroStation.`r`n" +
            "HMAPS_DIR = $dir`r`n" +
            "MS_ADDINPATH > `$(HMAPS_DIR)`r`n" +
            "MS_DGNAPPS > HMaps`r`n"
    $ok = Put-File $text (Get-ApplCfgPath $ms)
    if ($ok) { Write-Host "Tu nap HMaps voi moi User: $(Get-ApplCfgPath $ms)" }
    if ($menuLib -and (Test-Path $menuLib)) {
        $dst = Get-MenuLibPath $ms
        try {
            New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
            Copy-Item -LiteralPath $menuLib -Destination $dst -Force
            Write-Host "Menu HMaps tren thanh menu: $dst"
        }
        catch {
            if (Copy-AsAdmin $menuLib $dst) { Write-Host "Menu HMaps tren thanh menu: $dst" }
            else { Write-Host "Chua chep duoc menu (dong MicroStation roi chay lai bo cai): $dst" }
        }
    }
    return $ok
}

function Copy-AsAdmin($src, $dst) {
    try { Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "/c copy /y `"$src`" `"$dst`"" } catch { }
    return (Test-Path $dst)
}

# Shortcut "HMaps" (Desktop, Start menu) mo MicroStation voi User HMaps, va muc "Mo bang HMaps"
# khi bam chuot phai file .dgn (HKCU, khong can admin) - giong gCadas.
function Get-ShortcutPaths {
    return @((Join-Path ([Environment]::GetFolderPath('Desktop')) 'HMaps.lnk'),
             (Join-Path ([Environment]::GetFolderPath('Programs')) 'HMaps.lnk'))
}

function Write-Shortcuts($ms) {
    $exe = Join-Path $ms 'ustation.exe'
    $sh = New-Object -ComObject WScript.Shell
    foreach ($lnk in Get-ShortcutPaths) {
        try {
            $s = $sh.CreateShortcut($lnk)
            $s.TargetPath = $exe
            $s.Arguments = "-wu$UserName"
            $s.WorkingDirectory = $ms
            $s.IconLocation = "$exe,0"
            $s.Description = 'HMaps - cong cu dia chinh tren MicroStation V8i'
            $s.Save()
            Write-Host "Shortcut: $lnk"
        }
        catch { Write-Host "Chua tao duoc shortcut $lnk : $($_.Exception.Message)" }
    }
    try {
        $prog = (Get-ItemProperty 'Registry::HKEY_CLASSES_ROOT\.dgn' -ErrorAction Stop).'(default)'
        if ($prog) {
            $k = "HKCU:\Software\Classes\$prog\shell\HMaps"
            New-Item -Path "$k\command" -Force | Out-Null
            Set-ItemProperty -Path $k -Name '(default)' -Value 'Mo bang HMaps'
            Set-ItemProperty -Path $k -Name 'Icon' -Value "`"$exe`",0"
            Set-ItemProperty -Path "$k\command" -Name '(default)' -Value "`"$exe`" -wu$UserName `"%1`""
            Write-Host "Chuot phai file .dgn: 'Mo bang HMaps'"
        }
    }
    catch { }
}

function Remove-Shortcuts {
    foreach ($lnk in Get-ShortcutPaths) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
    try {
        $prog = (Get-ItemProperty 'Registry::HKEY_CLASSES_ROOT\.dgn' -ErrorAction Stop).'(default)'
        if ($prog) { Remove-Item "HKCU:\Software\Classes\$prog\shell\HMaps" -Recurse -Force -ErrorAction SilentlyContinue }
    }
    catch { }
}

# Ban 0.8.0 dat User HMaps lam User mac dinh: tra lai User cu (nho trong HMaps-prev-user.txt).
# $removeProfile: go ca User HMaps (khi go cai dat).
function Remove-Workspace($ms, $removeProfile) {
    $ws = $null; try { $ws = Get-WorkspaceRoot $ms } catch { }
    if ($ws) {
        if ($removeProfile) { Remove-AsAdmin (Join-Path $ws "Users\$UserName.ucf") }
        Remove-AsAdmin (Join-Path $ws "System\ucm\StartUp$UserName.UCM")
    }
    foreach ($p in Get-PrefsDirs) {
        $dflt = Join-Path $p 'dfltuser.cfg'
        $prevF = Join-Path $p 'HMaps-prev-user.txt'
        if ((Test-Path $dflt) -and (Select-String -Path $dflt -Pattern "^\s*_USTN_USERNAME\s*=\s*$UserName\s*$" -Quiet)) {
            if (Test-Path $prevF) { [IO.File]::WriteAllText($dflt, "_USTN_USERNAME = $((Get-Content $prevF -Raw).Trim())`r`n", [Text.Encoding]::ASCII) }
            else { Remove-Item $dflt -Force }
        }
        Remove-Item $prevF -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host "=== HMaps cho MicroStation V8i ==="
    $ms = Find-MicroStation
    Write-Host "MicroStation: $ms"

    if ($Uninstall) {
        Remove-Workspace $ms $true
        Remove-Shortcuts
        Remove-AsAdmin (Get-ApplCfgPath $ms)
        Remove-AsAdmin (Join-Path $ms 'config\appl\HMaps.cfg.disabled')
        try { Remove-AsAdmin (Get-MenuLibPath $ms) } catch { }
        Write-Host "Da go tu nap va menu HMaps. Dong MicroStation roi xoa thu muc $Inst de go han."
        return
    }

    $stage = Join-Path $env:TEMP ('HMaps-stage-' + [DateTime]::Now.Ticks)
    New-Item -ItemType Directory -Force $stage | Out-Null
    $menuSrc = $null
    if ($Dll) {
        Copy-Item -LiteralPath $Dll (Join-Path $stage 'HMaps.dll')
        Copy-Item (Join-Path $Here 'update.ps1') $stage
        $v = (Get-Content (Join-Path (Split-Path -Parent $Dll) 'version.json') -Raw | ConvertFrom-Json).version
        $menuSrc = Join-Path (Split-Path -Parent $Dll) 'HMaps.dgnlib'
        if (-not (Test-Path $menuSrc)) { $menuSrc = Join-Path $Root 'installer\HMaps.dgnlib' }
    }
    elseif ($DevMode) {
        Write-Host "Che do ma nguon: bien dich tai may..."
        $dll = Build-Addin $ms
        Copy-Item $dll (Join-Path $stage 'HMaps.dll')
        Copy-Item (Join-Path $Here 'update.ps1') $stage
        $v = (Get-Content (Join-Path $Root 'version.json') -Raw | ConvertFrom-Json).version
        $menuSrc = Join-Path $Root 'installer\HMaps.dgnlib'
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
        if ($info.menu) {
            $menuSrc = Join-Path $stage 'HMaps.dgnlib'
            $wc.DownloadFile("$Raw/HMaps.dgnlib", $menuSrc)
            if ((Get-FileHash $menuSrc -Algorithm SHA256).Hash -ne $info.menu.ToUpper()) { Write-Host "Menu tai ve sai ma kiem tra - bo qua."; $menuSrc = $null }
        }
    }
    if ($menuSrc -and (Test-Path $menuSrc)) { Copy-Item $menuSrc (Join-Path $stage 'HMaps.dgnlib') -Force -ErrorAction SilentlyContinue; $menuSrc = Join-Path $stage 'HMaps.dgnlib' }

    New-Item -ItemType Directory -Force $Inst | Out-Null
    Swap-In (Join-Path $stage 'HMaps.dll') (Join-Path $Inst 'HMaps.dll')
    Copy-Item (Join-Path $stage 'update.ps1') $Inst -Force
    $h = (Get-FileHash (Join-Path $Inst 'HMaps.dll') -Algorithm SHA256).Hash
    [IO.File]::WriteAllText((Join-Path $Inst 'version.json'), "{ `"version`": `"$v`", `"sha256`": `"$h`" }")
    [IO.File]::WriteAllText((Join-Path $Inst 'repo.txt'), $Repo)
    Write-Host "Da cai HMaps $v vao $Inst"

    if (Write-Autoload $ms $menuSrc) {
        # Tu nap qua config\appl roi: bo UCM cua ban cu (khong nap 2 lan), tra lai User mac dinh cu.
        Remove-Workspace $ms $false
        Write-Profile $ms $false | Out-Null
        Write-Shortcuts $ms
        Write-Host ""
        Write-Host "[XONG] Mo MicroStation bang shortcut 'HMaps' (hoac chon User 'HMaps'): giao dien HMaps"
        Write-Host "       nam phia tren. User khac (LandMap, gCadas...): menu 'HMaps' tren thanh menu."
    }
    elseif (Write-Profile $ms $true) {
        Write-Shortcuts $ms
        Write-Host ""
        Write-Host "[XONG] Mo MicroStation bang shortcut 'HMaps' (User '$UserName' da dat lam mac dinh):"
        Write-Host "       HMaps tu nap va mo giao dien HMaps."
    }
    else {
        Write-Host ""
        Write-Host "[XONG MOT PHAN] Chua ghi duoc cau hinh tu nap. Trong MicroStation go key-in:"
        Write-Host "    mdl load `"$Inst\HMaps.dll`""
    }
    if ($DevMode -and -not $Dll) {
        Write-Host ""
        Write-Host "Ghi chu: cac DLL tham chieu cua Bentley da duoc chep vao $(Join-Path $Root 'refs')"
    }
}
catch {
    Write-Host ""
    Write-Host "[THAT BAI] $($_.Exception.Message)"
    Write-Host "Hay gui lai noi dung cua so nay (va build.log neu co)."
    exit 1
}
