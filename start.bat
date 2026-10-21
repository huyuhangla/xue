@echo off
setlocal
cd /d "%~dp0"
where mvn >nul 2>nul
if errorlevel 1 goto nomaven
echo Starting backend with Maven...
call mvn spring-boot:run
goto end

:nomaven
echo [ERROR] Maven not found.
echo Install Maven 3.9+ and add it to PATH, or use demo.bat with the prebuilt jar.
echo Download: https://maven.apache.org/download.cgi

:end
pause
