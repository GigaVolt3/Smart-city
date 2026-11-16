@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title CivicAI launcher

rem ---------------------------------------------------------------------------
rem  CivicAI control panel
rem    1  API + website      2  API only        3  website only
rem    4  mobile app in the emulator (same PC as host)
rem    5  reset app data     6  stop servers    0  exit
rem    7  build + install on a phone plugged in over USB
rem    8  install / repair every dependency (Python, Node, Flutter)
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
set "KEY_PROPERTIES=%ROOT%\mobile\android\key.properties"
set "KEYSTORE=%ROOT%\mobile\android\keystore\civicai-release.jks"
set "KEY_ALIAS=civicai"
set "DEVICES_TXT=%TEMP%\civicai-devices.txt"
set "PHONES_TXT=%TEMP%\civicai-phones.txt"
set "BOOT_TXT=%TEMP%\civicai-boot.txt"
set "INSTALL_TXT=%TEMP%\civicai-install.txt"
set "KILL_TXT=%TEMP%\civicai-kill.txt"
set "PHONE_INFO_TXT=%TEMP%\civicai-phone-info.txt"

set "PY=python"
if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"

set "CURL=%SystemRoot%\System32\curl.exe"
if not exist "%CURL%" set "CURL=curl"

set "SDK=%LOCALAPPDATA%\Android\Sdk"
set "ADB=%SDK%\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"
set "EMULATOR=%SDK%\emulator\emulator.exe"
if not exist "%EMULATOR%" set "EMULATOR=emulator"
set "SDKMANAGER=%SDK%\cmdline-tools\latest\bin\sdkmanager.bat"
set "AVDMANAGER=%SDK%\cmdline-tools\latest\bin\avdmanager.bat"
if not exist "%SDKMANAGER%" for /d %%D in ("%SDK%\cmdline-tools\*") do if exist "%%D\bin\sdkmanager.bat" set "SDKMANAGER=%%D\bin\sdkmanager.bat"
if not exist "%AVDMANAGER%" for /d %%D in ("%SDK%\cmdline-tools\*") do if exist "%%D\bin\avdmanager.bat" set "AVDMANAGER=%%D\bin\avdmanager.bat"
set "SYSIMAGE=system-images;android-34;google_apis;x86_64"
set "AVD_TXT=%TEMP%\civicai-avds.txt"

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
echo    [7] Install the app on a phone connected by USB cable
echo    [8] Install / repair all dependencies  (Python, Node, Flutter)
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
if "%CHOICE%"=="7" goto do_phone
if "%CHOICE%"=="8" goto do_deps
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
call :ensure_app
if errorlevel 1 goto action_done
"%ADB%" !ADB_SEL! reverse tcp:%API_PORT% tcp:%API_PORT% >nul 2>&1
echo.
echo Launching CivicAI in the emulator...
"%ADB%" !ADB_SEL! shell am start -n %ACTIVITY% >nul 2>&1
if errorlevel 1 "%ADB%" !ADB_SEL! shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo.
echo   The app talks to this PC through 10.0.2.2:%API_PORT%
echo   (the emulator's alias for the host machine; API already started).
echo   If it ever says "Cannot reach the CivicAI service", tap Change on the
echo   sign-in screen and enter:  10.0.2.2:%API_PORT%
goto action_done

:do_reset
call :require_device
if errorlevel 1 goto action_done
"%ADB%" -s !EMU_SER! shell pm clear %PACKAGE%
echo.
echo   App data cleared. Next launch starts on 10.0.2.2:%API_PORT%, signed out.
goto action_done

:do_stop
echo Stopping API and website...
call :kill_port %API_PORT%
call :kill_port %WEB_PORT%
echo Done.
goto action_done

:do_phone
call :start_api
call :wait_api
if errorlevel 2 goto action_done
call :require_phone
if errorlevel 1 goto action_done
call :ensure_keystore
call :build_apk
if errorlevel 1 goto action_done
call :install_apk
if errorlevel 1 goto action_done
"%ADB%" !ADB_SEL! shell am start -n %ACTIVITY% >nul 2>&1
echo.
call :lan_url
echo   The app is installed. On the sign-in screen tap Change next to "Server:"
echo   and enter the address above (or %PHONE_URL%), then sign in with
echo   citizen@demo.civicai / DemoPass1!
goto action_done

:do_deps
set "FORCE_DEPS=1"
call :ensure_python_deps
call :ensure_node_deps
call :ensure_flutter_deps
call :ensure_keystore
set "FORCE_DEPS="
echo.
echo   Dependency check finished. Anything that failed is listed above.
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
call :deps_ready && (echo    Deps     : ready) || (echo    Deps     : missing - run option 8)
exit /b 0

:deps_ready
if not exist "%ROOT%\.venv\Scripts\python.exe" exit /b 1
if not exist "%ROOT%\dashboard\node_modules\vite\bin\vite.js" exit /b 1
exit /b 0

:port_up
rem curl answers in milliseconds; `netstat -ano` costs ~18 s on this machine,
rem and the status block probes two ports on every menu redraw.
if exist "%CURL%" (
  "%CURL%" -s -o nul -m 1 "http://127.0.0.1:%~1/" >nul 2>&1
  if !errorlevel! EQU 7 exit /b 1
  exit /b 0
)
set "UP="
for /f "tokens=5" %%P in ('netstat -ano -p tcp ^| findstr /c:":%~1 " ^| findstr /i "LISTENING"') do set "UP=1"
if defined UP exit /b 0
exit /b 1

:kill_port
rem Fast path: the launcher's own windows carry a known title, so no port scan.
if "%~1"=="%API_PORT%" (
  taskkill /FI "WINDOWTITLE eq CivicAI API*" /T /F > "%KILL_TXT%" 2>&1
  findstr /i /c:"SUCCESS" "%KILL_TXT%" >nul 2>&1
  if not errorlevel 1 (
    echo   stopped the CivicAI API window
    exit /b 0
  )
)
if "%~1"=="%WEB_PORT%" (
  taskkill /FI "WINDOWTITLE eq CivicAI Web*" /T /F > "%KILL_TXT%" 2>&1
  findstr /i /c:"SUCCESS" "%KILL_TXT%" >nul 2>&1
  if not errorlevel 1 (
    echo   stopped the CivicAI Web window
    exit /b 0
  )
)
rem Fallback: a server started by hand owns the port, so ask who is listening -
rem but only if something is listening at all (the netstat scan is slow).
call :port_up %~1
if errorlevel 1 exit /b 0
for /f "tokens=5" %%P in ('netstat -ano -p tcp ^| findstr /c:":%~1 " ^| findstr /i "LISTENING"') do (
  echo   stopping PID %%P on port %~1
  taskkill /PID %%P /T /F >nul 2>&1
)
exit /b 0

:start_api
call :port_up %API_PORT% && (
  echo API already running on %API_URL%
  exit /b 0
)
call :ensure_python_deps
if errorlevel 1 exit /b 1
echo Starting the API server...
rem The nested quotes keep a .venv path that contains spaces (the repo folder
rem name does) working inside cmd /k.
start "CivicAI API" /D "%ROOT%" cmd /k ""%PY%" -m uvicorn backend.main:app --host 0.0.0.0 --port %API_PORT%"
exit /b 0

:start_web
call :port_up %WEB_PORT% && (
  echo Website already running on %WEB_URL%
  exit /b 0
)
call :ensure_node_deps
if errorlevel 1 exit /b 1
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
set "EMU_SER="
"%ADB%" devices > "%DEVICES_TXT%" 2>nul
for /f "skip=1 tokens=1,2" %%A in ('type "%DEVICES_TXT%"') do (
  set "SER=%%A"
  if /i "%%B"=="device" if /i "!SER:~0,9!"=="emulator-" if not defined EMU_SER set "EMU_SER=!SER!"
)
if not defined EMU_SER exit /b 1
exit /b 0

:require_device
call :device_ready && exit /b 0
echo.
echo   No emulator attached. Use option 4 first - it boots one for you.
exit /b 1

:ensure_emulator
call :device_ready && exit /b 0
call :ensure_sdk
if errorlevel 1 exit /b 1
call :ensure_avd
if errorlevel 1 exit /b 1
echo Starting the %AVD% emulator...
start "CivicAI Emulator" "%EMULATOR%" -avd %AVD% -netdelay none -netspeed full
echo Waiting for the emulator to attach ^(up to 2 minutes^)...
for /l %%I in (1,1,60) do (
  call :device_ready && goto emu_boot
  call :sleep 2
)
echo.
echo   The emulator did not attach. Look at the "CivicAI Emulator" window for errors.
echo   If it complains about the AVD, delete %USERPROFILE%\.android\avd\%AVD%.avd and retry.
exit /b 1

:emu_boot
echo Waiting for Android to finish booting ^(first boot can take a few minutes^)...
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

rem Installs platform-tools + emulator + a system image when the SDK is missing.
:ensure_sdk
if exist "%ADB%" if exist "%EMULATOR%" exit /b 0
echo.
echo   The Android SDK is incomplete:
echo     SDK folder : %SDK%
echo     adb        : %ADB%
echo     emulator   : %EMULATOR%
echo.
if not exist "%SDKMANAGER%" goto sdk_manual
choice /c yn /n /m "  Download platform-tools, the emulator and a system image (~1.5 GB)? [y/n] "
if errorlevel 2 goto sdk_manual
echo   Accepting SDK licences...
(echo y & echo y & echo y & echo y & echo y & echo y & echo y & echo y) | call "%SDKMANAGER%" --sdk_root="%SDK%" --licenses >nul 2>&1
echo   Downloading SDK packages ^(several minutes^)...
call "%SDKMANAGER%" --sdk_root="%SDK%" --install "platform-tools" "emulator" "platforms;android-34" "%SYSIMAGE%"
if errorlevel 1 goto sdk_manual
if not exist "%ADB%" goto sdk_manual
if not exist "%EMULATOR%" goto sdk_manual
echo   SDK components installed.
exit /b 0

:sdk_manual
echo.
echo   Install the Android emulator once, then run option 4 again:
echo     1. Install Android Studio (includes the SDK, adb and the emulator)
echo        https://developer.android.com/studio
echo     2. Or with cmdline-tools on PATH:
echo        sdkmanager --install "platform-tools" "emulator" "platforms;android-34" "%SYSIMAGE%"
echo     3. Create an AVD named %AVD% in Android Studio ^(Device Manager^).
echo.
echo   You can still use the website ^(option 1^) and the published APK on a phone.
exit /b 1

rem Reuses any existing AVD; creates %AVD% from the installed system image if none.
:ensure_avd
"%EMULATOR%" -list-avds > "%AVD_TXT%" 2>nul
findstr /x /c:"%AVD%" "%AVD_TXT%" >nul 2>&1 && exit /b 0
for /f "usebackq delims=" %%A in ("%AVD_TXT%") do (
  set "AVD=%%A"
  echo   Using the existing emulator "!AVD!" instead of creating a new one.
  exit /b 0
)
echo   No Android virtual device found - creating "%AVD%"...
if not exist "%SDKMANAGER%" goto avd_manual
if not exist "%SDK%\system-images\android-34\google_apis\x86_64\" (
  echo   Downloading the system image ^(~1 GB^)...
  (echo y & echo y & echo y & echo y & echo y) | call "%SDKMANAGER%" --sdk_root="%SDK%" --licenses >nul 2>&1
  call "%SDKMANAGER%" --sdk_root="%SDK%" --install "%SYSIMAGE%"
)
if not exist "%SDK%\system-images\android-34\google_apis\x86_64\" goto avd_manual
echo no | call "%AVDMANAGER%" create avd -n %AVD% -k "%SYSIMAGE%" -d pixel_6
if errorlevel 1 goto avd_manual
"%EMULATOR%" -list-avds > "%AVD_TXT%" 2>nul
findstr /x /c:"%AVD%" "%AVD_TXT%" >nul 2>&1 && exit /b 0

:avd_manual
echo.
echo   Could not create the emulator. Create one named %AVD% in Android Studio
echo   ^(Device Manager ^> Create device ^> Pixel 6 ^> Android 14^), then retry.
exit /b 1

:ensure_app
call :ensure_emulator
if errorlevel 1 exit /b 1
set "ADB_SEL=-s !EMU_SER!"
call :build_apk
if errorlevel 1 exit /b 1
call :install_apk
if errorlevel 1 (
  echo   Install failed. Re-run option 4, or check adb devices.
  exit /b 1
)
exit /b 0

rem --------------------------- dependencies ----------------------------------

:ensure_python_deps
rem Creates .venv and installs backend\requirements.txt when they are missing.
if not exist "%ROOT%\.venv\Scripts\python.exe" (
  where python >nul 2>&1
  if errorlevel 1 (
    echo.
    echo   Python is not on PATH. Install Python 3.11 or newer, tick
    echo   "Add python.exe to PATH" in the installer, then retry:
    echo     https://www.python.org/downloads/windows/
    exit /b 1
  )
  echo Installing backend dependencies ^(first run only^)...
  echo   Creating the virtual environment in .venv ...
  python -m venv "%ROOT%\.venv"
  if errorlevel 1 (
    echo   Could not create .venv - check the python output above.
    exit /b 1
  )
)
set "PY=%ROOT%\.venv\Scripts\python.exe"
rem The import probe costs ~1.5 s, so a marker written after a successful install
rem makes the common start instant. Option 8 sets FORCE_DEPS and reinstalls.
if not defined FORCE_DEPS (
  if exist "%ROOT%\.venv\.deps-ok" exit /b 0
  "%PY%" -c "import fastapi, uvicorn, sqlalchemy, sklearn" >nul 2>&1
  if not errorlevel 1 (
    > "%ROOT%\.venv\.deps-ok" echo 1
    exit /b 0
  )
)
echo   Installing the packages from backend\requirements.txt ...
"%PY%" -m pip install --disable-pip-version-check --quiet --upgrade pip
"%PY%" -m pip install --disable-pip-version-check -r "%ROOT%\backend\requirements.txt"
if errorlevel 1 (
  echo.
  echo   pip could not install the backend packages - scroll up for the reason.
  exit /b 1
)
> "%ROOT%\.venv\.deps-ok" echo 1
echo   Backend dependencies ready.
exit /b 0

:ensure_node_deps
rem Installs the dashboard npm packages when node_modules is missing.
if exist "%ROOT%\dashboard\node_modules\vite\bin\vite.js" exit /b 0
where npm >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Node.js ^(with npm^) is not on PATH. Install the LTS build, then retry:
  echo     https://nodejs.org/en/download
  exit /b 1
)
echo Installing dashboard dependencies ^(first run only, about a minute^)...
pushd "%ROOT%\dashboard"
if exist package-lock.json (
  call npm ci --no-audit --no-fund
) else (
  call npm install --no-audit --no-fund
)
set "NPM_RC=!errorlevel!"
popd
if not "!NPM_RC!"=="0" (
  echo.
  echo   npm install failed - scroll up for the reason.
  exit /b 1
)
echo   Dashboard dependencies ready.
exit /b 0

:ensure_flutter_deps
rem Fetches the Dart packages listed in pubspec.yaml.
if exist "%ROOT%\mobile\.dart_tool\package_config.json" exit /b 0
where flutter >nul 2>&1
if errorlevel 1 exit /b 1
echo Installing Flutter packages ^(first run only^)...
pushd "%ROOT%\mobile"
call flutter pub get
popd
exit /b 0

:ensure_keystore
rem One-time release key: every later build keeps the same signature, so an
rem install on top of an older copy is accepted instead of rejected.
if exist "%KEY_PROPERTIES%" if exist "%KEYSTORE%" exit /b 0
set "KEYTOOL="
if exist "%JAVA_HOME%\bin\keytool.exe" set "KEYTOOL=%JAVA_HOME%\bin\keytool.exe"
if not defined KEYTOOL if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe" set "KEYTOOL=%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe"
if not defined KEYTOOL for /f "delims=" %%K in ('where keytool 2^>nul') do if not defined KEYTOOL set "KEYTOOL=%%K"
if not defined KEYTOOL (
  echo   keytool not found - the APK will be signed with the debug key.
  exit /b 0
)
echo Creating the release signing key ^(one time only^)...
if not exist "%ROOT%\mobile\android\keystore" mkdir "%ROOT%\mobile\android\keystore" >nul 2>&1
"%KEYTOOL%" -genkeypair -v -keystore "%KEYSTORE%" -storetype JKS -alias %KEY_ALIAS% -keyalg RSA -keysize 2048 -validity 10950 -storepass civicai -keypass civicai -dname "CN=CivicAI, OU=Smart City, O=CivicAI, L=Kolkata, ST=West Bengal, C=IN" >nul 2>&1
if errorlevel 1 (
  echo   Could not create the key - the APK will be signed with the debug key.
  exit /b 0
)
> "%KEY_PROPERTIES%" echo storePassword=civicai
>> "%KEY_PROPERTIES%" echo keyPassword=civicai
>> "%KEY_PROPERTIES%" echo keyAlias=%KEY_ALIAS%
>> "%KEY_PROPERTIES%" echo storeFile=../keystore/civicai-release.jks
echo   Release key ready: mobile\android\keystore\civicai-release.jks
exit /b 0

rem --------------------------- build + install -------------------------------

:build_apk
rem Rebuilds when the APK is missing, or when a release key exists but the
rem current APK was still signed with the throwaway debug key.
set "RESIGN="
if exist "%KEY_PROPERTIES%" if not exist "%ROOT%\mobile\build\.release-signed" set "RESIGN=1"
if exist "%APK%" if not defined RESIGN (
  echo APK already built: %APK%
  exit /b 0
)
where flutter >nul 2>&1
if errorlevel 1 (
  if exist "%APK%" (
    echo   Flutter is not on PATH - using the existing APK.
    exit /b 0
  )
  echo.
  echo   No APK in mobile\build and Flutter is not on PATH.
  echo   Download the ready build instead:
  echo     https://github.com/GigaVolt3/Smart-city/releases/latest/download/app-release.apk
  echo   Save it as: %APK%
  exit /b 1
)
call :ensure_flutter_deps
call :ensure_keystore
echo Building the release APK ^(1-3 minutes^)...
pushd "%ROOT%\mobile"
call flutter build apk --release
set "BUILD_RC=!errorlevel!"
popd
if not "!BUILD_RC!"=="0" (
  echo   Build failed - scroll up for the Flutter/Gradle output.
  exit /b 1
)
if not exist "%APK%" (
  echo   Build failed: %APK% is still missing.
  exit /b 1
)
if exist "%KEY_PROPERTIES%" > "%ROOT%\mobile\build\.release-signed" echo 1
exit /b 0

:install_apk
if not exist "%APK%" (
  echo   No APK to install at %APK%
  exit /b 1
)
echo Installing the APK ^(this can take a minute over USB^)...
"%ADB%" !ADB_SEL! install -r "%APK%" > "%INSTALL_TXT%" 2>&1
if not errorlevel 1 goto install_ok
rem A copy signed with a different key cannot be upgraded in place.
findstr /c:"INSTALL_FAILED_UPDATE_INCOMPATIBLE" /c:"signatures do not match" /c:"INSTALL_FAILED_ALREADY_EXISTS" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 (
  echo   An older CivicAI build is already installed with a different key.
  echo   Removing it and retrying...
  "%ADB%" !ADB_SEL! uninstall %PACKAGE% >nul 2>&1
  "%ADB%" !ADB_SEL! install -r "%APK%" > "%INSTALL_TXT%" 2>&1
  if not errorlevel 1 goto install_ok
)
rem Streaming installs break on flaky USB links; retry by pushing the file first.
findstr /c:"INSTALL_FAILED_INVALID_APK" /c:"INSTALL_FAILED_INTERNAL_ERROR" /c:"INSTALL_FAILED_INSUFFICIENT_STORAGE" /c:"broken pipe" /c:"closed" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 (
  echo   Retrying with the non-streaming installer...
  "%ADB%" !ADB_SEL! install --no-streaming -r "%APK%" > "%INSTALL_TXT%" 2>&1
  if not errorlevel 1 goto install_ok
)
echo.
echo   adb could not install the app:
type "%INSTALL_TXT%"
echo.
call :install_help
exit /b 1

:install_ok
"%ADB%" !ADB_SEL! shell pm list packages %PACKAGE% | findstr /c:"package:%PACKAGE%" >nul
if errorlevel 1 (
  echo   The APK did not register with the device - retry once.
  exit /b 1
)
echo APK installed.
exit /b 0

:install_help
findstr /c:"INSTALL_FAILED_OLDER_SDK" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 echo   ^> The phone runs Android 6 or older; the app needs Android 7.0 (API 24)^+.
findstr /c:"INSTALL_FAILED_NO_MATCHING_ABIS" /c:"INSTALL_FAILED_CPU_ABI_INCOMPATIBLE" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 echo   ^> The phone CPU is not supported by this APK.
findstr /c:"INSTALL_FAILED_INSUFFICIENT_STORAGE" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 echo   ^> Free up about 200 MB on the phone and retry.
findstr /c:"INSTALL_FAILED_USER_RESTRICTED" /c:"INSTALL_FAILED_VERIFICATION_FAILURE" /c:"INSTALL_FAILED_ABORTED" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 echo   ^> Allow it on the phone: Xiaomi/Redmi - Developer options ^> "Install via USB"; any phone - accept the install prompt.
findstr /c:"INSTALL_PARSE_FAILED" /c:"Invalid file" /c:"not a valid zip" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 echo   ^> The APK file is corrupt - delete it and rebuild ^(option 7^).
findstr /c:"INSTALL_FAILED_UPDATE_INCOMPATIBLE" "%INSTALL_TXT%" >nul 2>&1
if not errorlevel 1 echo   ^> Uninstall the existing CivicAI app from the phone, then retry.
echo.
echo   If the phone shows its own message, it usually means one of:
echo     - "App not installed": an older copy exists - uninstall it first.
echo     - "Blocked by Play Protect": tap "More details" then "Install anyway".
echo     - "Can't install unknown apps": allow your browser/file manager to
echo       install unknown apps in the phone settings.
exit /b 0

:require_phone
rem Finds exactly one USB phone (emulators ignored) and pins adb to it.
"%ADB%" devices > "%PHONES_TXT%" 2>nul
set "ADB_SEL="
set "PHONE="
set "PHONE_COUNT=0"
for /f "skip=1 tokens=1,2" %%A in ('type "%PHONES_TXT%"') do (
  set "SER=%%A"
  if /i "%%B"=="device" if /i not "!SER:~0,9!"=="emulator-" (
    set /a PHONE_COUNT+=1
    set "PHONE=!SER!"
  )
)
if "!PHONE_COUNT!"=="0" (
  echo.
  echo   No phone is connected. On the phone:
  echo     Settings ^> About phone ^> tap "Build number" seven times,
  echo     then Settings ^> Developer options ^> USB debugging ^> on.
  echo   Plug the cable in, accept "Allow USB debugging" on the phone, retry.
  exit /b 1
)
if !PHONE_COUNT! GTR 1 (
  echo.
  echo   More than one phone is connected - unplug all but the one to use.
  exit /b 1
)
set "ADB_SEL=-s !PHONE!"
"%ADB%" -s !PHONE! shell getprop ro.build.version.release > "%PHONE_INFO_TXT%" 2>nul
set "PHONE_OS="
if exist "%PHONE_INFO_TXT%" set /p PHONE_OS=<"%PHONE_INFO_TXT%"
echo   Phone attached: !PHONE!  ^(Android !PHONE_OS!^)
exit /b 0

:lan_url
rem Prints the address the phone must use for the API on the local network.
set "LAN_IP="
set "LAN_ALT="
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /c:"IPv4"') do (
  set "IP=%%I"
  set "IP=!IP: =!"
  if not defined LAN_ALT set "LAN_ALT=!IP!"
  if /i "!IP:~0,8!"=="192.168." set "LAN_IP=!IP!"
)
if not defined LAN_IP if defined LAN_ALT set "LAN_IP=!LAN_ALT!"
if not defined LAN_IP set "LAN_IP=YOUR-PC-IP"
set "PHONE_URL=%LAN_IP%:%API_PORT%"
echo   Server address for the phone: %PHONE_URL%
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
