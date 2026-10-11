# Polaroid vibe — iOS prototype

Bản SwiftUI native để thử luồng Camera → Preview → Gallery → Detail trên iPhone, iOS 17 trở lên. Không có package bên ngoài.

## Chạy trên iPhone

Mở `PolaroidVibe.xcodeproj`, chọn scheme `PolaroidVibe`, chọn iPhone đang kết nối và bấm Run. Project đang dùng team Apple Development có sẵn trên máy này. Trên máy khác, chọn lại team trong Signing & Capabilities. Bundle ID bản thử: `com.nguyenphu.polaroidvibe.preview`.

## Luồng thử

1. Camera live chạy ngay trong màn Camera bằng AVFoundation. Bật/tắt flash và grid, chuyển zoom 1x/2x. Nút ảnh mở PhotosPicker native. Nút quay về mở Gallery (màn Home chưa có trong phạm vi thiết kế).
2. Nút tỉ lệ mở bộ chọn theo Figma: dọc 23:31, vuông 1:1, ngang 99:62. X hủy; ✓ xác nhận. Nút filter mở Sunny / Soft / Old Days / Clear. Chụp xong vào Preview để chỉnh cường độ và chất film, đối chiếu ảnh gốc.
3. Trong **Edit Your Image**, ảnh hiển thị trong khung Polaroid, rộng tối đa 280 pt và giữ nguyên tỉ lệ chụp. Nút **Edit Text** mở bàn phím nhập chữ Mynerve; chạm chữ để sửa và kéo chữ trong viền giấy trắng. Hai thanh chỉnh dùng vạch custom; núm kéo dùng glass native trên iOS 26+. Nhấn **Save** để ghép khung Polaroid, lưu vào bộ sưu tập riêng và mở Gallery.
4. Gallery mở toàn màn hình, vuốt ảnh chính hoặc chạm thumbnail để chọn ảnh. Chạm ảnh chính mở **Image Detail**: sửa, xóa trong app hoặc **Save To Device** lưu ảnh có khung và chữ vào thư viện Ảnh. Bộ sưu tập giữ được sau khi đóng app.

## Giới hạn bản thử

- UI Camera theo Figma node 1360:966. Native Button, ratio custom, PhotosPicker, SF Symbols; glassEffect/GlassEffectContainer thật trên iOS 26+, regularMaterial trên iOS 17–18. Nút chụp dùng asset chấm tròn gốc của Figma. Glass có thể sáng và phản xạ khác mock tĩnh.
- Viewfinder live áp LUT và texture ngay khi đổi preset, dùng chung FilmEngine với ảnh chụp. Preview xử lý ở queue riêng, cạnh dài 640 px, tối đa 15 fps; ảnh chụp vẫn tối đa 1600 px. Zoom 2x dùng digital zoom của camera wide trên iPhone 13. Test phần cứng flash/chụp cần iPhone thật; simulator dùng ảnh mẫu khi bấm chụp.
- Ảnh được xoay theo EXIF, crop giữa theo tỉ lệ đã xác nhận, cạnh dài tối đa 1600 px. Ảnh trong Gallery và chia sẻ là JPEG đã áp màu; viền giấy và chữ đã được ghép vào file xuất. Bản gốc được lưu riêng cho các ảnh mới để sửa tiếp không chồng màu.
- Dùng 4 LUT gốc từ prototype web với `CIColorCubeWithColorSpace` trong sRGB. Grain có seed cố định; softness, ám màu và vignette là bản thử native, chưa tương đương từng pixel với texture web.
- Không có cloud, đăng nhập, RAW pipeline hoặc crop tùy chỉnh. Sửa ảnh có bản gốc sẽ thay bản đang xem và giữ ngày chụp; ảnh cũ thiếu bản gốc tạm khóa sửa. Gỡ app sẽ mất Gallery riêng.
- LUT và ảnh mẫu giữ nguyên phạm vi thử nghiệm local; ghi công G’MIC nằm trong `PolaroidVibe/Resources/ATTRIBUTION-gmic.txt`. Xem research/giấy phép trong `../film-preset-lab/README.md` trước khi phân phối sản phẩm.

## Kiểm tra

Trong Xcode bấm **Product → Test** trên iPhone Simulator. Các test kiểm tra:

- 4 LUT thật render được, cường độ 0 giữ nguyên màu.
- 8 điểm đầu/cuối RGB của từng Hald LUT khớp pixel nguồn PNG, kiểm tra thứ tự trục và color space.
- Grain ổn định; ba tỉ lệ crop được giữ qua render và giới hạn cạnh dài 1600 px.
- Flash/grid/zoom; ratio draft, hủy và xác nhận; preset picker và chụp từ Camera.
- Luồng đổi 4 preset → so ảnh gốc → lưu → Gallery → Detail; ảnh còn sau relaunch.

```sh
xcodebuild -project ios/PolaroidVibe.xcodeproj -scheme PolaroidVibe \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/PolaroidVibeBuild CODE_SIGNING_ALLOWED=NO test
```

## Đối chiếu thiết kế Camera

[Figma Camera](https://www.figma.com/design/wjurDK02g218hn0usIzGyI/Testing-AI?node-id=1360-966). Frame chuẩn 390 × 844; safe area thật do iOS quản lý. Camera, Edit, Gallery và Detail đã được cập nhật theo các frame Figma trong phiên thiết kế; UI dùng SF Pro Rounded, chữ trên ảnh dùng Mynerve (OFL). Album chung vẫn tạm hoãn theo `../docs/shared-albums-plan.md`.
