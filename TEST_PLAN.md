# TEST PLAN — AETHELGARD BIOTECH (GODOT 4.x)

Tài liệu kịch bản kiểm thử các cơ chế cốt lõi của trò chơi theo đặc tả kỹ thuật.

---

## 1. Kiểm thử Quái chính (The Hunter) & Cơ chế Step-Linked + BFS
1. **Đứng im hoàn toàn:**
   - **Thao tác:** Vào pha Chase (hoặc nhấn `F9` -> `Force Start Chase`), đứng yên không nhấn `WASD`.
   - **Kết quả kỳ vọng:** Quái chính (`Hunter`) đứng im tại chỗ, bộ đếm bước (`200 STEPS` trong Dev Mode) không giảm.
2. **Di chuyển và Đường đi ngắn nhất (BFS):**
   - **Thao tác:** Đi bộ hoặc chạy qua các ngã rẽ chữ L, chữ T trong mê cung.
   - **Kết quả kỳ vọng:** Quái chính luôn đi theo đường hành lang ngắn nhất trên lưới BFS tới vị trí người chơi với tốc độ gấp đôi quãng đường người chơi di chuyển (`HUNTER_MULT = 2.0`), không bị kẹt góc tường.
3. **Chạy va vào tường:**
   - **Thao tác:** Nhấn giữ `W` đâm thẳng vào bức tường chắn trước mặt.
   - **Kết quả kỳ vọng:** Do vị trí thực tế không thay đổi (`last_frame_move_dist == 0`), bộ đếm bước không bị trừ oan và quái chính không tiến lên.
4. **Cột mốc 30 bước cuối & Sau 200 bước:**
   - **Thao tác:** Bật `F9` để quan sát số bước. Di chuyển cho đến khi số bước còn `<= 30`, sau đó tiếp tục đi hết `200` bước (`0 STEPS`).
   - **Kết quả kỳ vọng:**
     - Ngoài Dev Mode, số bước còn lại hoàn toàn ẩn khỏi màn hình HUD.
     - Ở `<= 30` bước, Hunter vào `final_mode` (mắt sáng rực, miễn nhiễm choáng từ cây lau nhà, đi xuyên qua vùng sợ tượng).
     - Khi hết `200` bước (`0 STEPS`), Hunter vào trạng thái `overtime_rage` cực mạnh, dịch chuyển áp sát theo đường BFS và lao tới kết liễu người chơi bằng hoạt ảnh Jumpscare `1.3s`.

---

## 2. Kiểm thử Quái nhỏ (Crawlers & Cultists)
1. **Độc lập với trạng thái đứng yên của người chơi:**
   - **Thao tác:** Trong pha Chase, đứng yên hoàn toàn khi có Crawler hoặc Cultist ở gần (hoặc nhấn `F9` -> `+Crawler` / `+Cultist`).
   - **Kết quả kỳ vọng:** Quái chính đứng yên, nhưng Crawler và Cultist **vẫn tiếp tục di chuyển theo thời gian thực** để tấn công người chơi.
2. **Hoạt ảnh Crawler cắn 4 giai đoạn:**
   - **Thao tác:** Để một Crawler tiếp cận người chơi.
   - **Kết quả kỳ vọng:** Crawler phóng lên bám chặt vào mặt camera, người chơi giãy giụa rồi dùng cây lau nhà giật phăng ném Crawler xuống sàn làm nổ vết máu. Sau 4 lần bị cắn (`4 / 4`), người chơi tử vong.

---

## 3. Kiểm thử Cây lau nhà (Mop), Nhiệm vụ & Tương tác
1. **Quota Ca làm việc (Work Shift):**
   - **Thao tác:** Lau 3 vũng chất thải xanh, kiểm tra 2 máy Terminal, và lau 3 vết máu đỏ (`+$15` mỗi vết).
   - **Kết quả kỳ vọng:** Vết máu biến mất sau khi lau (không thể lau lặp lại để farm tiền). Chỉ khi hoàn thành đủ cả **3 chất thải + 3 vết máu + 2 Terminal**, pha Chase mới kích hoạt.
2. **Chiến đấu bằng cây lau nhà trong pha Chase:**
   - **Thao tác:** Nhấn chuột trái (`LMB`) vào Crawler, Cultist và Hunter.
   - **Kết quả kỳ vọng:**
     - Crawler chết ngay lập tức (`-10%` độ bền).
     - Cultist bị choáng `3.5s` (`-33%` độ bền).
     - Hunter bị choáng `4.5s` ở lần đập 1 và 2 (`-33%` độ bền); ở lần đập thứ 3, Hunter gục xuống giả chết (`AMBUSH`) và vùng dậy tấn công ngay khi người chơi quay lưng đi!

---

## 4. Kiểm thử Tủ trốn (Locker) & Cổng bẫy (Gate Trap)
1. **Trốn trong tủ Locker:**
   - **Thao tác:** Nhấn `[E]` tại tủ Locker để vào/ra.
   - **Kết quả kỳ vọng:** Camera nằm gọn trong tủ nhìn qua khe cửa sắt, xoay chuột nhìn hai bên mượt mà, nhấn `[E]` bước ra ngoài không bị kẹt tường. Nếu trốn ngay trước mắt Hunter, Hunter sẽ tới cửa tủ kiểm tra và kéo người chơi ra.
2. **Đóng cổng an ninh:**
   - **Thao tác:** Nhấn `[E]` tại cổng bẫy (`Gate Trap`).
   - **Kết quả kỳ vọng:** Cổng sập xuống trong 30 giây, chặn đường BFS của Hunter.

---

## 5. Kiểm thử Meta-Horror (Pause & Quit)
1. **Nhấn Pause (`ESC`) khi quái ở gần:**
   - **Thao tác:** Trong pha Chase, nhấn `ESC` khi Hunter cách `<= 12` bước và khi `< 6` bước.
   - **Kết quả kỳ vọng:** Ở `<= 12` bước bị trừ `-10` bước và nháy đỏ; ở `< 6` bước bị xử tử ngay lập tức.
2. **Bấm Quit / Abandon Shift trong pha Chase:**
   - **Thao tác:** Mở Pause Menu trong pha Chase và bấm `QUIT TO MENU` nhiều lần.
   - **Kết quả kỳ vọng:** Hiện hộp thoại cảnh báo đỏ `"YOU DON'T HAVE THE AUTHORITY TO LEAVE JUST YET."`. Cố bấm lần 2–3 khiến Hunter xuất hiện ngay trước mặt người chơi (`2.0m`), gầm rú và trừ bước; lần 4 bị xử tử.

---

## 6. Kiểm thử Đêm 5, Hành lang Bí mật & Đa kết cục
1. **Hành lang Bí mật Đêm 5 (`Omega Sanctuary`):**
   - **Thao tác:** Nhảy tới Đêm 5 (`F9` -> `N5`), đi tới tọa độ cánh cửa bí mật ở bức tường phía Bắc `(r=0, c=13)` và bước vào hành lang dài có 3 bệ thờ.
   - **Kết quả kỳ vọng:** Khi ở trong hành lang bí mật, bộ đếm bước dừng giảm và quái nhỏ ngừng truy đuổi. Tương tác đủ 3 bệ thờ (`Pedestals`) mở khóa phong ấn True Ending.
2. **Fake Ending ($1 Billion) vs True Ending:**
   - **Thao tác:** Thoát khỏi Đêm 5 khi chưa đủ 15 Relics / 3 bệ thờ (hoặc bấm `CS:$1B` trong `F9`) so với khi đã kích hoạt đủ 3 bệ thờ / 15 Relics (`CS:True`).
   - **Kết quả kỳ vọng:**
     - **Fake Ending:** Người chơi nhận thông báo tiền thưởng `$1,000,000,000.00 ($1 BILLION)` trước khi màn hình điện thoại và toàn bộ màn hình trên Trái Đất chuyển sang màu đỏ, phát tán Thực thể ra toàn cầu.
     - **True Ending:** Phong ấn Omega khóa chặt từ bên trong, ngăn chặn cuộc phát tán.

---

## 7. Kiểm thử Dev Mode (`F9`)
- **Thao tác:** Nhấn `F9` trong lúc đang chơi, bật/tắt các checkbox, bấm nút đóng `✕` hoặc nhấn `F9` lần nữa.
- **Kết quả kỳ vọng:** Game **không bị đơ/đóng băng** khi mở hay đóng bảng `F9`; chuột tự động hiện ra để bấm nút và tự động khóa lại vào tâm ngắm khi đóng bảng hoặc khi click vào màn hình 3D.
