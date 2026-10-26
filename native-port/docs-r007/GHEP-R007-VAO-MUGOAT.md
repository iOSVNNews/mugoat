# Ghép engine R007 vào Mugoat (nhánh mugoat-r007-engine)

## Nguồn
- Mugoat `main` (6f061d1) tách từ GTA V iOS port 1.3.1 (commit 0953cb7).
- R007 = "GTA NEW GEN / Mugoat-NewGen-Regeneration-R007": port gốc 1.4.4 (kevinerikjs, MIT) cộng các bản sửa Regeneration R001–R007.
- Ghép 3 chiều: gốc chung 0953cb7, nhánh `r007-engine` chứa app R007 đặt trên gốc đó.

## Lấy của R007 (sửa giật và mất bản đồ)
- Toàn bộ engine và renderer:
  - `Source/*` (EngineHost.c, MetalRenderer, NativeAssets.m, NativeThreads.c…);
  - `Scripts/prepare_*` (khoảng 45 bản vá engine theo tên hàm);
  - `ShaderTool`, `Vendor/blink` (chạy mod .asi), opus.
- Memory guard và distance streaming của R005–R007: thu hồi RAM theo di chuyển, RAM dự trữ theo máy, tránh nền xám.
- Các công tắc thử nghiệm của 1.4.3/1.4.4, mặc định bật: tải texture thông minh, giảm texture lớn, ưu tiên nhân CPU nhanh, nén texture trong suốt.
- `game_0.c` được biên dịch tối ưu (bỏ `-O0`).
- Build bằng Xcode 26.2: bản kiểm tra của R007 cho thấy Xcode cũ làm FPS thấp hơn hẳn.

## Giữ của Mugoat
- Toàn bộ giao diện `App/*` (màn hình chính, nút, cài đặt, camera kéo, mod manager, cheat menu, save, online, voice).
- Online và voice chat:
  - `online-bridge`, `prepare_online_exports.py`, `prepare_online_c.py` (chạy sau cùng);
  - `MugoatVoiceMixAudio` trộn vào âm thanh game.
- Các hàm C mà App Mugoat gọi được giữ lại ở cuối EngineHost.c (khối "Mugoat additions"):
  - camera chạm, chuột;
  - cheat console (bị chặn khi online);
  - hồi sinh bệnh viện, thoát xe khẩn cấp, bỏ qua cảnh kẹt (chạy theo lượt script "main" như R007);
  - spawn xe theo tên (`MugoatSpawnVehicleNamed`, chạy qua spawner của R007).
- Bundle ID `vn.iosvn.mugoat` (giữ save), phiên bản 2.1 (21), quyền micro.

## Thay đổi
- Mục "RAM cho game" giờ là giới hạn RAM (`PGSetMemoryCap`). Engine R007 tự quyết định vùng nhớ dự trữ.
- Mục mới trong Cài đặt: "Mượt & giữ bản đồ (R007)", gồm 5 công tắc engine, thu hồi theo di chuyển, RAM dự trữ và khoảng cách thu hồi.
- iOS tối thiểu là 16.0, theo shader Metal 3 của R007.
- Chưa đưa giao diện của R007 vào (Menyoo, turbo, nhập âm thanh xe, Việt hóa đóng sẵn). Phần C của chúng vẫn có nhưng không có nút bật.

## Cần kiểm tra trên máy
- Build CI chưa chạy: đây là lần đầu biên dịch bản ghép này.
- Thử 15–20 phút cùng một tuyến đường: FPS, nền/đường có bị xám không, có văng không.
- Thử online và voice chat, cheat menu, spawn xe.
