@echo off
rem HMaps - bo cai cho MicroStation V8i. Tai file nay ve va nhay dup.
echo === Cai dat HMaps cho MicroStation V8i ===
set "HMAPS_PS1=%TEMP%\HMaps-setup.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=3072; (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/luantvu/HMaps-Public/main/setup.ps1','%HMAPS_PS1%')"
if errorlevel 1 goto :neterr
powershell -NoProfile -ExecutionPolicy Bypass -File "%HMAPS_PS1%" %*
echo.
pause
exit /b 0
:neterr
echo [LOI] Khong tai duoc bo cai. Kiem tra ket noi mang roi thu lai.
pause
exit /b 1
