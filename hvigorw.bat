@if "%DEBUG%" == "" @echo off
@rem ##########################################################################
@rem
@rem  Hvigor startup script for Windows
@rem
@rem ##########################################################################

@rem Set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" setlocal

set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

@rem Resolve any "." and ".." in APP_HOME to make it shorter.
for %%i in ("%APP_HOME%") do set APP_HOME=%%~fi

@rem Prefer DevEco JBR and hvigor when available.
if exist "C:\Program Files\Huawei\DevEco\jbr\bin\java.exe" set PATH=C:\Program Files\Huawei\DevEco\jbr\bin;%PATH%
if exist "C:\Program Files\Huawei\DevEco\sdk" set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco\sdk
if exist "C:\Program Files\Huawei\DevEco\tools\hvigor\bin\hvigorw.js" if exist "C:\Program Files\Huawei\DevEco\tools\node\node.exe" (
  "C:\Program Files\Huawei\DevEco\tools\node\node.exe" "C:\Program Files\Huawei\DevEco\tools\hvigor\bin\hvigorw.js" %*
  if "%ERRORLEVEL%" == "0" goto hvigorwEnd
  goto fail
)

@rem Fallback for installations that keep the product directory name as "DevEco Studio".
if exist "C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe" set PATH=C:\Program Files\Huawei\DevEco Studio\jbr\bin;%PATH%
if exist "C:\Program Files\Huawei\DevEco Studio\sdk" set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk
if exist "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" if exist "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" (
  "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" %*
  if "%ERRORLEVEL%" == "0" goto hvigorwEnd
  goto fail
)

set WRAPPER_MODULE_PATH=%DIRNAME%\hvigorw.js
set NODE_EXE=node.exe
@rem set NODE_OPTS="--max-old-space-size=8192 --expose-gc"

goto start

:start
if not defined NODE_OPTS set NODE_OPTS="--"

@rem Find node.exe
if defined NODE_HOME goto findNodeFromNodeHome

%NODE_EXE% --version >NUL 2>&1
if "%ERRORLEVEL%" == "0" goto execute

echo.
echo ERROR: NODE_HOME is not set and no 'node' command could be found in your PATH.
echo.
echo Please set the NODE_HOME variable in your environment to match the
echo location of your NodeJs installation.

goto fail

:findNodeFromNodeHome
set NODE_HOME=%NODE_HOME:"=%
set NODE_EXE_PATH=%NODE_HOME%/%NODE_EXE%

if exist "%NODE_EXE_PATH%" goto execute
echo.
echo ERROR: NODE_HOME is not set and no 'node' command could be found in your PATH.
echo.
echo Please set the NODE_HOME variable in your environment to match the
echo location of your NodeJs installation.

goto fail

:execute
@rem Execute hvigor
"%NODE_EXE%" "%NODE_OPTS%" "%WRAPPER_MODULE_PATH%" %*

if "%ERRORLEVEL%" == "0" goto hvigorwEnd

:fail
exit /b 1

:hvigorwEnd
if "%OS%" == "Windows_NT" endlocal

:end
