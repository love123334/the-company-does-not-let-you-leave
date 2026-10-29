# THE COMPANY DOES NOT LET YOU LEAVE — AETHELGARD BIOTECH (GODOT 4.x)

Phiên bản hoàn chỉnh trên **Godot Engine 4.x** của tựa game kinh dị sinh tồn góc nhìn thứ nhất `game_v8_observer_fixed-preset.html`.

---

## 1. Cách mở và chạy Project

1. Mở **Godot Engine 4.x** (đã kiểm thử tương thích hoàn toàn trên Godot `4.7.2-stable`).
2. Chọn **Import** / **Open** và trỏ tới thư mục `d:\escape\new-game-project\project.godot`.
3. Nhấn **F5** (hoặc nút **Run Project** ở góc phải trên) để khởi chạy scene chính [`scenes/main.tscn`](file:///d:/escape/new-game-project/scenes/main.tscn).
4. Hoặc chạy trực tiếp từ dòng lệnh:
   ```powershell
   & "D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "d:\escape\new-game-project"
   ```

---

## 2. Phím điều khiển (Controls)

| Phím / Chuột | Chức năng |
|---|---|
| `W`, `A`, `S`, `D` | Di chuyển nhân vật |
| `Shift` | Chạy nhanh (Sprint — tiêu hao Stamina, tăng FOV) |
| `Chuột` | Xoay góc nhìn camera (hoặc nhìn qua khe cửa khi trốn trong tủ Locker) |
| `Chuột trái (LMB)` | Lau dọn chất thải/vết máu (Pha Work) • Đập quái bằng cây lau nhà (Pha Chase) |
| `E` | Tương tác: Lau dọn, kiểm tra Terminal, nhặt Keycard/Relic, đọc Note, đóng Cổng bẫy, trốn/ra khỏi tủ Locker |
| `F` | Bật / tắt đèn pin (`Flashlight`) |
| `B` | Ném mồi hóa học (`Chemical Bait`) dụ Crawlers và Cultists trong 12 giây |
| `R` | Kích hoạt minigame `Containment Override` trong pha Chase (thành công đẩy lùi Hunter `+20 steps`) |
| `ESC` | Tạm dừng (`Pause`) hoặc đóng bảng đọc tài liệu / Dev Panel |
| `F9` | Bật / tắt bảng **Dev Mode / Debug Panel** (hiện số bước truy đuổi, nhảy đêm, bất tử, test cutscene...) |

---

## 3. Cấu trúc thư mục & Kiến trúc hệ thống

- [`project.godot`](file:///d:/escape/new-game-project/project.godot): Cấu hình project Godot 4.x và các Autoload (`GameData`, `SoundEffects`).
- [`scenes/main.tscn`](file:///d:/escape/new-game-project/scenes/main.tscn): Scene chính chứa `WorldEnvironment`, `MapGenerator`, `Player`, `Entities` và `HUD`.
- [`scripts/main.gd`](file:///d:/escape/new-game-project/scripts/main.gd): Điều phối vòng lặp 5 đêm, chuyển pha `WORK` -> `CHASE`, tính bước truy đuổi, xử lý chiến đấu bằng cây lau nhà, Meta-horror Pause/Quit và Dev Mode.
- [`scripts/player.gd`](file:///d:/escape/new-game-project/scripts/player.gd): Bộ điều khiển FPS, Stamina, 2 cánh tay lao công + cây lau nhà 3D, hoạt ảnh lau sàn, hoạt ảnh vung cây lau nhà đập quái, hoạt ảnh 4 giai đoạn bị Crawler cắn vào mặt và khóa camera Jumpscare.
- [`scripts/hunter.gd`](file:///d:/escape/new-game-project/scripts/hunter.gd): Quái chính (`Subject Zero`) với model giải phẫu 3D v7, thuật toán tìm đường ngắn nhất **BFS trên lưới mê cung**, luật di chuyển **Step-Linked** (`2.0x` quãng đường người chơi, đứng im tuyệt đối khi người chơi đứng im), cơ chế choáng/giả chết phục kích (`AMBUSH`), trạng thái bất bại `final_mode` (`<= 30` bước) và `overtime_rage` (sau `200` bước).
- [`scripts/crawler.gd`](file:///d:/escape/new-game-project/scripts/crawler.gd): Quái nhỏ 6 chân bò sàn/tường/trần, truy đuổi độc lập theo thời gian thực ngay cả khi người chơi đứng im.
- [`scripts/cultist.gd`](file:///d:/escape/new-game-project/scripts/cultist.gd): Giáo phái đêm 3+ cầm dao găm nghi lễ và đèn hương xích đung đưa, truy đuổi theo thời gian thực.
- [`scripts/statue.gd`](file:///d:/escape/new-game-project/scripts/statue.gd): Tượng đá quan sát (`Weeping Observer`) đêm 2+, chỉ di chuyển khi người chơi không nhìn và đẩy lùi Hunter trong bán kính `9.0m`.
- [`scripts/map_generator.gd`](file:///d:/escape/new-game-project/scripts/map_generator.gd): Sinh mê cung 3D, tầng lửng Mezzanine 2F, lồng sắt nhốt quái, tủ Locker, cổng bẫy, và **Hành lang Bí mật Đêm 5 (`Night5SecretCorridor`)** với 3 bệ thờ.
- [`scripts/hud.gd`](file:///d:/escape/new-game-project/scripts/hud.gd): Màn hình Main Menu 3D động, HUD trong game, trình chiếu Cutscene động 60fps (`csLoop`), hộp thoại Meta-horror Quit và bảng Debug `F9`.
- [`scripts/game_data.gd`](file:///d:/escape/new-game-project/scripts/game_data.gd): Dữ liệu 5 bản đồ mê cung, cấu hình độ khó 5 đêm, nội dung Lore Notes và kịch bản Cutscene (bao gồm Fake Ending `$1,000,000,000` và True Ending).
- [`scripts/sound_effects.gd`](file:///d:/escape/new-game-project/scripts/sound_effects.gd): Bộ tổng hợp âm thanh thủ tục (`Procedural Audio Synthesizer`) tạo tiếng bước chân, tiếng còi báo động, nhịp tim, tiếng gầm và nhạc nền rùng rợn không cần file âm thanh ngoài.
