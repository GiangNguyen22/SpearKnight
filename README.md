# 🗡️ SpearKnight: Dungeon Quest (Ver 1.0)

**SpearKnight: Dungeon Quest** là tựa game 2D Action Platformer nhập vai xây dựng trên Godot Engine 4.7. Người chơi sẽ điều khiển các anh hùng dấn thân vào Hầm Ngục Hắc Ám, tiêu diệt quái vật, thu thập chìa khóa cổ và chinh phục Chúa Tể Hầm Ngục.

---

## 🎮 Tính năng nổi bật (Ver 1.0)

- **3 Lớp Nhân Vật Độc Đáo**:
  - ⚔️ **Hiệp Sĩ Thiết Giáp (Knight)**: Cân bằng, sát thương đâm thương nguyên tố, khả năng Lướt bóng ma (Dash) và Nảy tường (Wall Jump).
  - 🔮 **Phù Thủy Hầm Ngục (Sorceress)**: Sát thương phép thuật bùng nổ, bắn cầu lửa diện rộng (AOE).
  - 🏹 **Cung Thủ Trinh Sát (Ranger)**: Tốc độ di chuyển cao, bắn tên xuyên thấu nhiều kẻ địch.
- **Hệ Thống Màn Chơi & Lưu Tiến Trình**:
  - Hỗ trợ lưu tiến trình màn chơi (`Continue`), số lượng xu, chìa khóa và cài đặt âm thanh.
  - Các tầng hầm ngục phong phú kèm Bẫy, Nền nhảy, NPC Trưởng Làng và Động Boss.
- **Cơ chế Đánh & Hiệu Ứng (Juice)**:
  - Hit-stop (khựng khung hình va chạm), Screen Shake (rung màn hình), VFX Nổ tia lửa (Hit Spark) và Sóng thương.
- **Giao Diện & Âm Thanh Chuyên Nghiệp**:
  - Giao diện Pause, Shop mua sắm, Cài đặt BGM / SFX độc lập.

---

## 🛠️ Hướng dẫn Chạy Game (Godot 4.7+)

1. Clone dự án về máy:
   ```bash
   git clone https://github.com/GiangNguyen22/SpearKnight.git
   ```
2. Mở dự án bằng **Godot Engine 4.7+**.
3. Nhấn **F5** hoặc bấm **Play** để khởi chạy Menu chính (`Scenes/Levels/menu.tscn`).

---

## 🕹️ Phím Điều Khiển (Controls)

| Phím | Hành động |
|------|-----------|
| **A / D** hoặc **Mũi tên Trái / Phải** | Di chuyển Trái / Phải |
| **Space** | Nhảy / Nhảy đôi (Double Jump) |
| **Shift** | Lướt nhanh (Dash) |
| **J / Left Click** | Tấn công / Bắn chưởng |
| **K** | Đổi thuộc tính nguyên tố |
| **Esc** | Tạm dừng (Pause Menu) |

---

## 📂 Cấu Trúc Thư Mục Dự Án

```text
Scenes/
├── Actors/       # Player, Enemy, Boss, NPC
├── Levels/       # Menu, Level 01-04, Options
├── Managers/     # GameManager, AudioManager, DialogueManager
├── Prefabs/      # Bullet, Coin, Key, Trap, Platform
└── UI/           # Character Select, Pause, Shop, Dialogue Box
```
