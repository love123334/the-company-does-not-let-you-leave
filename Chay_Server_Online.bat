@echo off
title The Company Does Not Let You Leave - Cloud Relay Server
color 0a
echo =================================================================
echo   THE COMPANY DOES NOT LET YOU LEAVE - ONLINE RELAY SERVER
echo =================================================================
echo   Server trung gian giup ket noi nguoi choi khac mang (4G / Wi-Fi)
echo   KHONG CAN MO CONG (PORT FORWARD), KHONG CAN HIEN THI IP!
echo.
cd /d "%~dp0server"
node relay_server.js
pause
