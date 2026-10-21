@echo off
setlocal
cd /d "%~dp0"
if exist "dist\crop-nutrition-agent-1.0.0.jar" goto runjar
echo Prebuilt jar not found. Falling back to Maven...
call start.bat
goto end

:runjar
echo Starting OHCP Crop Nutrition Agent (prebuilt jar)...
echo Open http://localhost:8080/ in your browser.
java -jar "dist\crop-nutrition-agent-1.0.0.jar"

:end
pause
