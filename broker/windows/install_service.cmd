@echo off
rem sets MOSQUITTO_DIR system environment variable to point to absolute path of
rem folder containing this script and then installs mosquitto as a system service.
set HERE=%~dp0
set HERE=%HERE:~0,-1%
setx -m MOSQUITTO_DIR "%HERE%"
set MOSQUITTO_DIR=%HERE%
if not "%MOSQUITTO_DIR%" == "%HERE%" (
	echo Please create system environment variable MOSQUITTO_DIR pointing to %HERE%.
) else (
	mosquitto install
)
pause
