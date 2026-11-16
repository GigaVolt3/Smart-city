@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title CivicAI launcher

rem ---------------------------------------------------------------------------
rem  CivicAI control panel
rem    1  API + website      2  API only        3  website only
rem    4  mobile app in the emulator (same PC as host)
rem    5  reset app data     6  stop servers    0  exit
rem ---------------------------------------------------------------------------

rem Strip the trailing backslash so quoted paths like "%ROOT%\mobile" stay valid.
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "API_URL=http://127.0.0.1:8000"
set "WEB_URL=http://127.0.0.1:5173"
set "API_PORT=8000"
set "WEB_PORT=5173"
set "AVD=ms_test"
set "PACKAGE=com.civicai.civicai"
set "ACTIVITY=com.civicai.civicai/.MainActivity"
set "APK=%ROOT%\mobile\build\app\outputs\flutter-apk\app-release.apk"
set "DEVICES_TXT=%TEMP%\civicai-devices.txt"
set "BOOT_TXT=%TEMP%\civicai-boot.txt"

set "PY=python"
if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"

set "CURL=%SystemRoot%\System32\curl.exe"
if not exist "%CURL%" set "CURL=curl"
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"
set "EMULATOR=%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe"
if not exist "%EMULATOR%" set "EMULATOR=emulator"

rem Direct action mode: `start-civicai.bat 4` runs one option and exits.
set "CIVICAI_ARG=%~1"
if defined CIVICAI_ARG (
  set "CHOICE=%~1"
  goto dispatch
)

:menu
cls
echo ===============================================================
echo    CivicAI  -  control panel
echo ===============================================================
call :show_status
echo ---------------------------------------------------------------
echo    [1] Start API server + website
echo    [2] Start API server only
echo    [3] Start website only
echo    [4] Open the mobile app in the emulator  (this PC as host)
echo    [5] Reset mobile app data (server back to 10.0.2.2:8000)
echo    [6] Stop API + website
echo    [0] Exit
echo ---------------------------------------------------------------
set "CHOICE="
set /p "CHOICE=Select an option: "
goto dispatch

:dispatch
if "%CHOICE%"=="1" goto do_all
if "%CHOICE%"=="2" goto do_api
if "%CHOICE%"=="3" goto do_web
if "%CHOICE%"=="4" goto do_app
if "%CHOICE%"=="5" goto do_reset
if "%CHOICE%"=="6" goto do_stop
if "%CHOICE%"=="0" goto end
echo.
echo Unknown option "%CHOICE%".
call :sleep 2
goto menu

rem --------------------------- actions ---------------------------------------

:do_all
call :start_api
call :wait_api
if errorlevel 2 goto action_done
call :start_web
call :wait_web
if errorlevel 2 goto action_done
start "" "%WEB_URL%"
echo.
echo   Website     : %WEB_URL%
echo   API docs    : %API_URL%/docs
echo   Mobile host : 10.0.2.2:%API_PORT%   (option 4 opens the app)
goto action_done

:do_api
call :start_api
call :wait_api
if errorlevel 2 goto action_done
echo.
echo   API docs: %API_URL%/docs
goto action_done

:do_web
call :start_web
call :wait_web
if errorlevel 2 goto action_done
start "" "%WEB_URL%"
echo.
echo   Website: %WEB_URL%
goto action_done

:do_app
call :start_api
call :wait_api
if errorlevel 2 goto action_done
call :ensure_emulator
if errorlevel 1 goto action_done
call :ensure_app
if errorlevel 1 goto action_done
"%ADB%" reverse tcp:%API_PORT% tcp:%API_PORT% >nul 2>&1
echo.
echo Launching CivicAI in the emulator...
"%ADB%" shell am start -n %ACTIVITY% >nul 2>&1
if errorlevel 1 "%ADB%" shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo.
echo   The app talks to this PC through 10.0.2.2:%API_PORT%
echo   (the emulator's alias for the host machine; API already started).
echo   If it ever says "Cannot reach the CivicAI service", tap Change on the
echo   sign-in screen and enter:  10.0.2.2:%API_PORT%
goto action_done

:do_reset
call :require_device
if errorlevel 1 goto action_done
"%ADB%" shell pm clear %PACKAGE%
echo.
echo   App data cleared. Next launch starts on 10.0.2.2:%API_PORT%, signed out.
goto action_done

:do_stop
echo Stopping API and website...
call :kill_port %API_PORT%
call :kill_port %WEB_PORT%
echo Done.
goto action_done

:action_done
echo.
if defined CIVICAI_ARG goto end
pause
goto menu

rem --------------------------- helpers ---------------------------------------

:show_status
call :port_up %API_PORT% && (echo    API      : running on %API_URL%) || (echo    API      : stopped)
call :port_up %WEB_PORT% && (echo    Website  : running on %WEB_URL%) || (echo    Website  : stopped)
call :device_ready && (echo    Emulator : attached) || (echo    Emulator : not running)
exit /b 0

:port_up
set "UP="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":%~1 " ^| findstr /i "LISTENING"') do set "UP=1"
if defined UP exit /b 0
exit /b 1

:kill_port
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":%~1 " ^| findstr /i "LISTENING"') do (
  echo   stopping PID %%P on port %~1
  taskkill /PID %%P /T /F >nul 2>&1
)
exit /b 0

:start_api
call :port_up %API_PORT% && (
  echo API already running on %API_URL%
  exit /b 0
)
echo Starting the API server...
start "CivicAI API" /D "%ROOT%" cmd /k "%PY% -m uvicorn backend.main:app --host 0.0.0.0 --port %API_PORT%"
exit /b 0

:start_web
call :port_up %WEB_PORT% && (
  echo Website already running on %WEB_URL%
  exit /b 0
)
if not exist "%ROOT%\dashboard\node_modules" (
  echo Installing dashboard dependencies ^(first run only^)...
  pushd "%ROOT%\dashboard"
  call npm install
  popd
)
echo Starting the web console...
start "CivicAI Web" /D "%ROOT%\dashboard" cmd /k npm run dev
exit /b 0

:wait_api
echo Waiting for the API at %API_URL%/health ...
for /l %%I in (1,1,60) do (
  "%CURL%" -s -f -m 2 -o nul "%API_URL%/health" >nul 2>&1
  if not errorlevel 1 (
    echo API is up.
    exit /b 0
  )
  call :sleep 1
)
echo.
echo   The API did not answer within 60 seconds - check the "CivicAI API" window.
exit /b 2

:wait_web
echo Waiting for the website at %WEB_URL% ...
for /l %%I in (1,1,60) do (
  "%CURL%" -s -f -m 2 -o nul "%WEB_URL%" >nul 2>&1
  if not errorlevel 1 (
    echo Website is up.
    exit /b 0
  )
  call :sleep 1
)
echo.
echo   The website did not answer within 60 seconds - check the "CivicAI Web" window.
exit /b 2

:device_ready
"%ADB%" devices > "%DEVICES_TXT%" 2>nul
findstr /r /c:"^emulator-[0-9]*[ 	]*device" "%DEVICES_TXT%" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:require_device
call :device_ready && exit /b 0
echo.
echo   No emulator attached. Use option 4 first - it boots one for you.
exit /b 1

:ensure_emulator
call :device_ready && exit /b 0
echo Starting the %AVD% emulator...
start "CivicAI Emulator" "%EMULATOR%" -avd %AVD% -netdelay none -netspeed full
"%ADB%" wait-for-device
echo Waiting for Android to finish booting ^(first boot can take a minute^)...
for /l %%I in (1,1,150) do (
  if exist "%BOOT_TXT%" del "%BOOT_TXT%" >nul 2>&1
  "%ADB%" shell getprop sys.boot_completed > "%BOOT_TXT%" 2>nul
  set "BOOT="
  if exist "%BOOT_TXT%" set /p BOOT=<"%BOOT_TXT%"
  if "!BOOT!"=="1" (
    call :sleep 3
    echo Emulator is ready.
    exit /b 0
  )
  call :sleep 2
)
echo.
echo   The emulator did not finish booting in 5 minutes.
echo   Start it once from Android Studio, then try option 4 again.
exit /b 1

:ensure_app
if not exist "%APK%" (
  echo Release APK not found - building it now ^(about a minute^)...
  pushd "%ROOT%\mobile"
  call flutter build apk --release
  popd
  if not exist "%APK%" (
    echo   Build failed: %APK% is still missing.
    exit /b 1
  )
)
echo Installing the latest APK on the emulator...
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo   Install failed. Re-run option 4, or check adb devices.
  exit /b 1
)
exit /b 0

:sleep
rem `timeout` refuses to run when stdin is redirected, so this uses ping.
rem ping -n 1 returns immediately; the +1 is what produces a real delay.
set /a "_N=%~1+1"
ping -n %_N% 127.0.0.1 >nul 2>&1
exit /b 0

:end
endlocal
exit /b 0
