@echo off
set LOGFILE=C:\GetInfo.txt
call :LOG >> %LOGFILE%
exit /B

:LOG
echo .
echo .
echo %DATE%
echo %TIME%
echo ----------------------------------------------------------- >> %LOGFILE%
echo Creating Admin User >> %LOGFILE%
echo ----------------------------------------------------------- >> %LOGFILE%
set /p pass="Enter admin password: "
net user /add CDWAdmin %pass% >> %LOGFILE%
new localgroup administrators CDWAdmin /add >> %LOGFILE%

echo ----------------------------------------------------------- >> %LOGFILE%
echo Software Report >> %LOGFILE%
echo ----------------------------------------------------------- >> %LOGFILE%
wmic product get name >> %LOGFILE%

echo ----------------------------------------------------------- >> %LOGFILE%
echo Drive Report >> %LOGFILE%
echo ----------------------------------------------------------- >> %LOGFILE%
wmic logicaldisk get caption,size,freespace >> %LOGFILE%

echo ----------------------------------------------------------- >> %LOGFILE%
echo OS Info >> %LOGFILE%
echo ----------------------------------------------------------- >> %LOGFILE%
wmic os get osarchitecture,buildnumber,caption,CSDVersion /format:csv >> %LOGFILE%