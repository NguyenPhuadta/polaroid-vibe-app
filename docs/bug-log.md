# Bug log

## DETAIL-002 — Image Detail hoặc Edit mở màn trống sau khi lưu ảnh mới

- Ngày ghi nhận: 2026-10-11.
- Hiện tượng: Đôi lúc chạm ảnh mới không hiện Image Detail; vào được Detail thì chạm Edit không mở editor.
- Điểm lỗi tìm thấy trong mã: Trạng thái mở modal và dữ liệu ảnh được lưu ở các biến riêng; nội dung modal có nhánh rỗng khi ảnh chưa được SwiftUI quan sát cùng lần mở.
- Sửa: Dùng `.sheet(item:)` và `.fullScreenCover(item:)` với payload chứa sẵn ảnh. Áp dụng cho Detail, Edit và luồng import của Gallery; bỏ Boolean mở màn riêng và nhánh nội dung rỗng.
- Trạng thái: Đã sửa mã và build; chờ kiểm tra thao tác trên iPhone. Giữ nguyên quy tắc sửa cùng ảnh và giữ ngày chụp.

## GAL-001 — Thumbnail Gallery chưa khớp hiệu ứng video tham chiếu

- Ngày ghi nhận: 2026-10-11.
- Trạng thái: Để xử lý sau theo yêu cầu của người dùng.
- Hiện tượng: Bản demo nghiêng và thu nhỏ thumbnail có chiều sâu nhưng chưa giống chuyển động trong video Pinterest. Lần chỉnh tiếp theo không đúng ý người dùng và đã được revert.
- Bản giữ lại: Demo đầu tiên, khoảng cách 19pt; góc xoay theo khoảng cách đến tâm, tối đa 65°; thu nhỏ tối đa 24%; lớp mờ hai mép 172pt. Ảnh chính vẫn dựng thẳng, giữ rồi rê để tilt.
- Mong muốn: Hiệu ứng phối cảnh/skew của dải thumbnail giống video. Cần đối chiếu và xác nhận lại cách hiểu chuyển động với người dùng trước khi chỉnh tiếp; không coi mô hình mặt trụ vừa thử là yêu cầu đã được chấp thuận.
- Tham chiếu: https://www.pinterest.com/pin/211174979742002/
- Video người dùng gửi: `/Users/nguyenhongphu/.codex/attachments/35b7ec47-d834-479b-894f-90bac894d23a/Ghi Màn hình 2026-10-11 lúc 15.52.52.mov`.
- Mã liên quan: `ios/PolaroidVibe/PolaroidVibeApp.swift`, hàm `thumbnailStrip(width:)`.

## DETAIL-001 — Ảnh cũ không có bản gốc để chỉnh lại preset

- Ngày ghi nhận: 2026-10-11.
- Trạng thái: Giới hạn dữ liệu cũ, để xử lý sau.
- Hiện tượng: Trước bản Image Detail mới, app chỉ lưu JPEG đã áp màu và khung Polaroid. Không thể khôi phục chính xác ảnh chưa áp màu từ file này.
- Xử lý hiện tại: Tạm khóa nút Sửa cho ảnh thiếu bản gốc. Ảnh được lưu từ bản mới giữ thêm PNG gốc riêng; editor xử lý từ bản gốc, Save cập nhật ảnh đang xem và giữ ngày chụp theo lựa chọn của người dùng.
- Không tự tạo bản gốc bằng cách bỏ khung hay đảo LUT; những cách đó không khôi phục các chi tiết đã mất.
