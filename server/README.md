# Hướng dẫn Deploy WebSocket Relay Server (Chơi Co-Op Xuyên Mạng)

Relay server này giúp toàn bộ người chơi kết nối vào cùng 1 sảnh game mà **không cần mở port (port forward)**, **không cần Hamachi/Radmin**, và **100% không lộ địa chỉ IP**.

---

### Cách 1: Chạy trực tiếp trên máy tính (Local / LAN / Chung Wi-Fi)
- Chỉ cần nhấp đúp file: **`Chay_Server_Online.bat`** ở thư mục gốc của game.
- Hoặc mở terminal gõ: `node server/relay_server.js`
- Game sẽ tự động kết nối qua `ws://127.0.0.1:8912`.

---

### Cách 2: Deploy lên Cloud miễn phí 24/7 (Khuyên dùng để chơi với bạn bè ở xa)

#### A. Deploy lên Render.com (Miễn phí 100%):
1. Đăng ký tài khoản miễn phí tại [render.com](https://render.com).
2. Tạo **New Web Service** -> Kết nối repo GitHub chứa thư mục dự án (hoặc thư mục `server/`).
3. Cài đặt:
   - **Root Directory**: `server`
   - **Build Command**: `npm install`
   - **Start Command**: `node relay_server.js`
4. Render sẽ cấp cho bạn một đường link HTTPS/WSS (ví dụ: `wss://escape-relay.onrender.com`).
5. Mở file `relay_config.json` trong game và điền link đó vào:
   ```json
   {
     "relay_url": "wss://escape-relay.onrender.com"
   }
   ```
6. Giờ đây bất kỳ ai mở game ở bất kỳ đâu (4G, Wi-Fi khác nhà) đều nhìn thấy phòng của nhau trên danh sách phòng và vào chơi ngay lập tức!

#### B. Deploy lên Glitch.com (Nhanh nhất, không cần thẻ tín dụng):
1. Vào [glitch.com](https://glitch.com) -> New Project -> `hello-node`.
2. Dán nội dung file `relay_server.js` và `package.json` vào.
3. Glitch cấp link (ví dụ: `escape-relay.glitch.me`).
4. Điền `wss://escape-relay.glitch.me` vào `relay_config.json`.
