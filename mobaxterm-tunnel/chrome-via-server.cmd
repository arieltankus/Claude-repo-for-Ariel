@echo off
rem ------------------------------------------------------------------
rem  chrome-via-server.cmd
rem  Opens Google Chrome through the MobaXterm SOCKS tunnel.
rem
rem  Before using it: start the tunnel in MobaXterm
rem  (menu Tools, "MobaSSHTunnel (port forwarding)", play button).
rem
rem  Chrome is started with its own profile folder ("ChromeViaServer"),
rem  so your normal Chrome is untouched, and the proxy settings always
rem  apply even when your normal Chrome is already open.
rem
rem  Usage:  chrome-via-server.cmd                 (opens a test page)
rem          chrome-via-server.cmd https://host    (opens that page)
rem ------------------------------------------------------------------

rem Must match the "Forwarded port" you typed in MobaSSHTunnel.
set "SOCKS_PORT=1080"

rem Separate Chrome profile used only for browsing through the server.
set "PROFILE_DIR=%LOCALAPPDATA%\ChromeViaServer"

rem Page to open when no address is given on the command line.
set "URL=%~1"
if "%URL%"=="" set "URL=https://ifconfig.me"

rem Find chrome.exe in the usual places.
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" (
    echo Could not find chrome.exe.
    echo Edit this file and set CHROME to the full path of chrome.exe.
    pause
    exit /b 1
)

rem --proxy-server        : send everything to the SOCKS5 proxy of the tunnel
rem --host-resolver-rules : never resolve names on this PC, let the server do it
rem --user-data-dir       : the separate profile described above
start "" "%CHROME%" --user-data-dir="%PROFILE_DIR%" --proxy-server="socks5://127.0.0.1:%SOCKS_PORT%" --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE 127.0.0.1" --no-first-run --new-window "%URL%"
