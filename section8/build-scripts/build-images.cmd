@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "SERVICES=configserver eurekaserver accounts loans cards"
set "PARALLEL=0"
set "PUSH=0"
set "ARGS="

rem Usage (run from the repo root):
rem   build-scripts\build-images.cmd                    build all services sequentially into the local Docker daemon
rem   build-scripts\build-images.cmd accounts cards      build only the named services
rem   build-scripts\build-images.cmd --parallel          build all services concurrently
rem   build-scripts\build-images.cmd -p accounts cards   build named services concurrently
rem   build-scripts\build-images.cmd --push              build locally, then `docker push` each image (needs `docker login`)
rem   build-scripts\build-images.cmd -p --push cards     combine flags and service names freely
for %%A in (%*) do (
    if /I "%%A"=="--parallel" (
        set "PARALLEL=1"
    ) else if /I "%%A"=="-p" (
        set "PARALLEL=1"
    ) else if /I "%%A"=="--push" (
        set "PUSH=1"
    ) else (
        set "ARGS=!ARGS! %%A"
    )
)

if not "!ARGS!"=="" (
    set "SERVICES=!ARGS!"
)

set "ACTION=built"
if "!PUSH!"=="1" set "ACTION=built and pushed"

if "!PARALLEL!"=="1" (
    call :build_parallel
) else (
    call :build_sequential
)
exit /b %errorlevel%

rem Reads the Jib <to><image> value straight out of the service's pom.xml so the image
rem ref used for `docker push` can never drift out of sync with what was just built.
rem Leaves the result in IMAGE_REF (read it with delayed expansion: !IMAGE_REF!).
:image_ref
set "IMAGE_REF="
for /f "usebackq tokens=1,* delims=>" %%X in (`findstr /C:"<image>" "%PROJECT_ROOT%\%~1\pom.xml"`) do set "IMAGE_REF=%%Y"
set "IMAGE_REF=%IMAGE_REF:</image>=%"
set "IMAGE_REF=!IMAGE_REF:${project.artifactId}=%~1!"
goto :eof

:build_sequential
for %%S in (%SERVICES%) do (
    echo ==^> Building image for %%S
    pushd "%PROJECT_ROOT%\%%S"
    call mvn compile jib:dockerBuild
    if errorlevel 1 (
        popd
        echo Build failed for %%S
        exit /b 1
    )
    popd
    if "!PUSH!"=="1" (
        call :image_ref %%S
        echo ==^> Pushing !IMAGE_REF!
        docker push "!IMAGE_REF!"
        if errorlevel 1 (
            echo Push failed for %%S
            exit /b 1
        )
    )
)
echo ==^> All images %ACTION%: %SERVICES%
exit /b 0

:build_parallel
set "LOG_DIR=%SCRIPT_DIR%.build-logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

for %%S in (%SERVICES%) do (
    if exist "%LOG_DIR%\%%S.done" del "%LOG_DIR%\%%S.done"
    if "!PUSH!"=="1" (
        call :image_ref %%S
        > "%LOG_DIR%\%%S.worker.cmd" (
            echo @echo off
            echo cd /d "%PROJECT_ROOT%\%%S"
            echo call mvn compile jib:dockerBuild ^> "%LOG_DIR%\%%S.log" 2^>^&1
            echo if not errorlevel 1 docker push "!IMAGE_REF!" ^>^> "%LOG_DIR%\%%S.log" 2^>^&1
            echo echo %%errorlevel%% ^> "%LOG_DIR%\%%S.done"
        )
    ) else (
        > "%LOG_DIR%\%%S.worker.cmd" (
            echo @echo off
            echo cd /d "%PROJECT_ROOT%\%%S"
            echo call mvn compile jib:dockerBuild ^> "%LOG_DIR%\%%S.log" 2^>^&1
            echo echo %%errorlevel%% ^> "%LOG_DIR%\%%S.done"
        )
    )
    echo ==^> Starting build for %%S (log: .build-logs\%%S.log)
    start "build-%%S" /B cmd /c "%LOG_DIR%\%%S.worker.cmd"
)

:waitloop
set "PENDING=0"
for %%S in (%SERVICES%) do (
    if not exist "%LOG_DIR%\%%S.done" set "PENDING=1"
)
if "!PENDING!"=="1" (
    timeout /t 2 /nobreak >nul
    goto waitloop
)

set "FAILED="
for %%S in (%SERVICES%) do (
    set /p RESULT=<"%LOG_DIR%\%%S.done"
    if not "!RESULT!"=="0" (
        set "FAILED=!FAILED! %%S"
    )
)

if "!FAILED!"=="" (
    echo ==^> All images %ACTION% successfully: %SERVICES%
    exit /b 0
) else (
    echo ==^> Build FAILED for:!FAILED!
    echo     See logs in "%LOG_DIR%" for details
    exit /b 1
)
