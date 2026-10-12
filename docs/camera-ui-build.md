# Camera UI — 11/10/2026

Thiết kế: https://www.figma.com/design/wjurDK02g218hn0usIzGyI/Testing-AI?node-id=1360-966

Đã build Camera, flash/grid, zoom, chọn tỉ lệ có hủy/xác nhận, chọn preset theo Figma. SwiftUI Button, SF Symbols, PhotosPicker, bộ chọn ratio custom theo Figma; glassEffect/GlassEffectContainer iOS 26+ và material fallback. Sáu chấm nút chụp dùng asset SVG gốc Figma đã lưu trong asset catalog.

AVCaptureSession + AVCaptureVideoDataOutput đưa buffer camera qua FilmEngine để hiển thị LUT/texture trực tiếp trong viewfinder. Crop dọc 23:31, vuông 1:1, ngang 99:62; cạnh dài tối đa 1600 px. Preview/export giữ tỉ lệ mới. Zoom 2x là digital zoom từ camera wide.

## Kiểm tra

- Device build: BUILD SUCCEEDED. Bản cuối cài thành công trên iPhone 13, bundle com.nguyenphu.polaroidvibe.preview.
- Simulator iPhone 13: 4 unit tests + 2 UI tests PASS. Kiểm tra LUT, giới hạn crop và ba tỉ lệ, flash/grid/zoom, ratio draft/cancel/confirm, chọn preset, lưu và persistence qua relaunch.
- Screenshot từng trạng thái đã đối chiếu tại ios/Previews/Camera.
- Device chưa chạy kiểm tra chụp/flash thực tế; lệnh launch bị từ chối vì máy khóa. Người dùng mở khóa và mở Polaroid vibe để test phần cứng.

## Điểm khác và phạm vi

- Glass native phản xạ/sáng khác mock Figma và tự thích nghi với hệ điều hành/accessibility.
- Status bar và home indicator do iOS vẽ; không đưa asset device chrome từ Figma vào app.
- Icon dọc native là biểu tượng chung, tỉ lệ ảnh thực tế vẫn 23:31.
- Zoom khởi đầu 1x, bấm sang 2x. Flash mặc định tắt.
- Nút quay về hiện mở Gallery vì màn Home chưa được thiết kế trong scope này.
- Preview/Gallery/Detail vẫn giữ UI cũ; chỉ cập nhật tên preset và hỗ trợ ảnh không vuông.
- Album chung tiếp tục tạm hoãn.

## Sửa bộ chọn ratio theo yêu cầu

Bỏ UISegmentedControl. Ba SwiftUI Button custom kích thước 44 × 44, gap 4, padding 4; nền chọn tròn 44, opacity 15%. Icon portrait SVG gốc Figma 16 × 24; square 16 × 16 và landscape 24 × 16, nét 1.714 và bo 4.571 như thiết kế. Lớp vỏ vẫn Liquid Glass. Hành vi draft/cancel/confirm giữ nguyên.

Kiểm tra bản custom: test CameraControlsAndRatioTransaction PASS; device BUILD SUCCEEDED. Screenshot ratio custom đã cập nhật trong ios/Previews/Camera.


## Sửa khoảng cách và live preset (2026-10-11)

Khi mở preset, bỏ padding top 36 làm frame dọc tràn xuống nút chụp. Tính chiều cao viewfinder từ chiều cao màn hình còn lại sau header và controls, chừa tối thiểu 16 pt dưới frame. Giữ nguyên ba tỉ lệ và selector custom.

Preview camera dùng AVCaptureVideoDataOutput, buffer BGRA xoay portrait 90°, xử lý LUT + texture bằng cùng FilmEngine với ảnh chụp. Queue riêng, bỏ frame trễ, throttle 15 fps và giới hạn cạnh dài 640 px; cache grain theo kích thước. Đổi preset cập nhật settings của queue ngay, frame tiếp theo dùng màu mới. Ảnh chụp vẫn lấy từ AVCapturePhotoOutput và render ở độ phân giải 1600 px.

UI test mới đo khoảng cách thật ở cả ba ratio trong chế độ preset và so pixel bên trong viewfinder khi chọn cả bốn preset bằng ảnh mẫu. Test simulator xác nhận layout và pipeline màu; độ mượt/flash/camera thực cần kiểm tra trên iPhone.

Verification: device BUILD SUCCEEDED, cài thành công lên iPhone 13. Simulator 4 unit + 3 UI tests PASS (`/tmp/PolaroidLivePreviewTests.xcresult`), bao gồm test mới kiểm tra gap và pixel preset. Tự mở app bị iOS từ chối vì máy đang khóa; user mở thủ công để test camera thật.


## Thanh preset: đúng thứ tự layer Figma 1360:949

Thanh 186 × 56 trên frame iPhone 390 pt (thu hẹp khi màn nhỏ), clip bo 41, nền #1F1F1F blend plusLighter. Bỏ glass của toàn track. Hàng nội dung cao 48, padding dọc 4, gap 0, nút padding ngang 16. Chữ SF Pro 16, tracking -0.31, selected semibold. Nút được chọn có fill trắng 10% và native clear interactive glass; các nút khác không có nền. Hai mép gradient rộng 60, cao 56 được chuyển thành alpha mask trên glass container riêng rồi compositing lên #111: tương đương overlay #111 opaque ↔ transparent, nhưng đảm bảo native glass cũng mờ theo mép thay vì nổi lên trên overlay. Gradient không chặn touch. Native glass không ánh xạ từng tham số refraction/depth của Figma.

Final verification: `/tmp/PolaroidPresetDeliveryTests.xcresult` PASS (đổi 4 preset, pixel preview thay đổi, gap ≥16 pt ở cả 3 ratio). Ảnh Soft/Clear đối chiếu Figma trong `ios/Previews/Camera/`. Device BUILD SUCCEEDED, cài thành công bản cuối trên iPhone; launch tự động bị từ chối do máy khóa trở lại.


## Điều chỉnh thanh preset theo yêu cầu mới (2026-10-11)

Toàn bộ thanh 186 × 56 dùng native regular Liquid Glass, cùng modifier với thanh ratio. Các nút bên trong là Button thường; preset được chọn có nền Capsule trắng 15% và chữ semibold, không có glass riêng. Mask hai mép chỉ áp dụng vào nội dung cuộn trước lớp glass, giữ vỏ glass liền mạch. Giữ live preset, auto-scroll và gap tối thiểu 16 pt.

Verification: `/tmp/PolaroidFullGlassTests.xcresult` PASS: đổi preset cập nhật pixel preview và gap ≥16 pt trên cả ba ratio. Screenshot Soft đã kiểm tra vỏ glass toàn thanh. Device BUILD SUCCEEDED và cài thành công; launch bị từ chối vì iPhone khóa.


## Rà lại spacing toàn màn Camera (2026-10-11)

Đối chiếu lại frame Figma 1360:864 (390 × 844): toolbar Back x16/y66/48 × 48; khung x20/y134/350 × 471; shutter x155/y637/80 × 80; hàng dưới y734/64; thanh preset y738/56; các capsule flash/grid và ratio/zoom y655/44. Safe area iPhone 13 là 47 trên / 34 dưới.

Header được sửa thành padding trên 19 + nút 48 + khoảng dưới 20 = 87 pt trong safe area. Trong chế độ preset, hàng dưới giảm từ 80 xuống đúng 64 pt, khoảng giữa hai hàng 17 pt, đáy cách safe area 12 pt: tổng controls 173 pt. Khung ảnh có khoảng cách tối thiểu 20 pt với nút Back và 32 pt với shutter. Khung tự thu nhỏ theo không gian còn lại, giữ nguyên ratio; vuông/ngang căn giữa vùng ảnh nên hai khoảng lớn hơn. Lề ngang khung và controls 20 pt; toolbar 16 pt. Giữ glass toàn thanh preset và selected nền thường theo yêu cầu mới.

Verification: 2 UI tests PASS (`/tmp/PolaroidSpacingTests.xcresult`), Camera controls/ratio transaction và preset pixel/gap. Khoảng toolbar/shutter đo trên iPhone 13 simulator: portrait 20/32 pt; square 80.67/92.33 pt; landscape 146/158 pt. Screenshot cả ba trạng thái preset đã kiểm tra. Device BUILD SUCCEEDED; bản mới cài thành công.
