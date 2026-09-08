@echo off
set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco\sdk
set JAVA_HOME=C:\Program Files\Huawei\DevEco\jbr
set PATH=C:\Program Files\Huawei\DevEco\jbr\bin;%PATH%
cd /d C:\Users\Andy\mashen-app
node hvigorw.js --mode project -p product=release -p buildMode=release --no-daemon assembleApp
