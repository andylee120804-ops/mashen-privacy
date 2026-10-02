@echo off
chcp 65001 >nul
rem ============================================================
rem 一键抓取解签支付日志（IAP 错误码）
rem 用法：
rem   1. 手机解锁，允许 USB 调试，插好数据线
rem   2. 双击本脚本（保持窗口打开）
rem   3. 手机上打开 App → 求签 → 解锁今日解签 → 复现失败
rem   4. 回到本窗口按 Ctrl+C 停止，把 iap-log.txt 发给 Claude
rem ============================================================
set HDC=C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe
if not exist "%HDC%" set HDC=C:\Program Files\Huawei\DevEco\sdk\default\openharmony\toolchains\hdc.exe

echo [1/3] 检查设备连接...
"%HDC%" list targets
echo.

echo [2/3] 清空旧日志...
"%HDC%" shell hilog -r

echo [3/3] 开始抓取（每 1 秒倾倒一次，持续追加到 iap-log.txt）。
echo      现在去手机上复现「解锁今日解签」失败，等 3 秒后 Ctrl+C 停止。
echo ------------------------------------------------------------
:loop
"%HDC%" shell hilog >> iap-log.txt 2>&1
timeout /t 1 /nobreak >nul
goto loop
