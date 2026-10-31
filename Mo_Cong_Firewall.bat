@echo off
chcp 65001 >nul
echo ====================================================================
echo  CẤP PHÉP TƯỜNG LỬA WINDOWS CHO GAME CO-OP (PORT 8910 & 8911 UDP)
echo ====================================================================
echo.
echo Đang thêm quy tắc tường lửa cho Godot và cổng 8910, 8911 UDP...

netsh advfirewall firewall add rule name="Antigravity Janitor Game (UDP 8910 In)" dir=in action=allow protocol=UDP localport=8910 profile=any
netsh advfirewall firewall add rule name="Antigravity Janitor Game (UDP 8911 In)" dir=in action=allow protocol=UDP localport=8911 profile=any
netsh advfirewall firewall add rule name="Antigravity Janitor Game (UDP 8910 Out)" dir=out action=allow protocol=UDP localport=8910 profile=any
netsh advfirewall firewall add rule name="Antigravity Janitor Game (UDP 8911 Out)" dir=out action=allow protocol=UDP localport=8911 profile=any

echo.
echo ====================================================================
echo  ĐÃ MỞ CỔNG TƯỜNG LỬA THÀNH CÔNG!
echo  Bây giờ 2 máy tính trên cùng Wi-Fi có thể kết nối ngay lập tức!
echo ====================================================================
pause
