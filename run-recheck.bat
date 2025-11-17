
@echo off
setlocal enabledelayedexpansion
rem Usage: run-recheck.bat [baseUrl] [--insecure]
rem Environment: NARCONET_URL can be used to set the base URL (e.g. http://localhost:8080)
rem Environment: NARCONET_INSECURE=1 can be used to force insecure TLS behavior

set "INSECURE=0"
set "URL_ARG="

rem Parse arguments: accept --insecure (or -k) and an optional URL
for %%A in (%*) do (
    if /I "%%~A"=="--insecure" set "INSECURE=1"
    if /I "%%~A"=="-k" set "INSECURE=1"
    if not defined URL_ARG (
        if /I not "%%~A"=="--insecure" if /I not "%%~A"=="-k" set "URL_ARG=%%~A"
    )
)

if defined URL_ARG (
    set "URL=%URL_ARG%"
) else (
    if defined NARCONET_URL (
        set "URL=%NARCONET_URL%"
    ) else (
        set "URL=https://localhost:6969"
    )
)

if defined NARCONET_INSECURE if "%NARCONET_INSECURE%"=="1" set "INSECURE=1"

set "ENDPOINT=%URL%/narconet/recheck"
echo Posting recheck to %ENDPOINT%
if "%INSECURE%"=="1" echo Insecure mode: TLS certificate validation will be skipped

set "TMPRESP=%TEMP%\narconet_response.json"
if exist "%TMPRESP%" del /f /q "%TMPRESP%" 2>nul

rem Prepare curl args if needed
set "CURL_EXTRA="
if "%INSECURE%"=="1" set "CURL_EXTRA=-k"

rem Prefer curl if available (native binary), otherwise fall back to PowerShell
if exist "%SystemRoot%\System32\curl.exe" (
  echo Using curl...
  "%SystemRoot%\System32\curl.exe" -S -s %CURL_EXTRA% -X POST "%ENDPOINT%" -H "Accept: application/json" -o "%TMPRESP%" -w "\nHTTP_CODE:%{http_code}\n"
  set "CURL_EXIT=%ERRORLEVEL%"
  if exist "%TMPRESP%" (
    type "%TMPRESP%"
    del /f /q "%TMPRESP%" 2>nul
  ) else (
    echo (no response body saved)
  )
  echo curl exit code: %CURL_EXIT%
  echo.
  pause
  exit /b %CURL_EXIT%
)

echo curl not found, using PowerShell Invoke-RestMethod...
set "PS_INSECURE_CMD="
if "%INSECURE%"=="1" set "PS_INSECURE_CMD=[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; "

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { %PS_INSECURE_CMD% $r = Invoke-RestMethod -Method Post -Uri '%ENDPOINT%' -TimeoutSec 120; $r | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 '$TMPRESP'; exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }"
set "PS_EXIT=%ERRORLEVEL%"
if exist "%TMPRESP%" (
  type "%TMPRESP%"
  del /f /q "%TMPRESP%" 2>nul
) else (
  echo (no response body saved)
)
echo PowerShell exit code: %PS_EXIT%
echo.
pause
exit /b %PS_EXIT%
