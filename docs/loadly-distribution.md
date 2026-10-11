# Phát hành bản thử iOS qua Loadly

Cập nhật: 11/10/2026. Chưa upload lên Loadly, chưa có link cài cho tester.

## Bản hiện tại

- Bundle ID: `com.nguyenphu.polaroidvibe.preview`.
- Debug device build đã build và cài thành công lên Chiyeuminhem.
- Profile development, `get-task-allow = true`, chỉ đăng ký 2 thiết bị.
- Profile hết hạn 18/10/2026 lúc 13:51 giờ Việt Nam. Hạn này độc lập với hạn lưu link trên Loadly.
- Gói demo được chuẩn bị ngoài repo: `/tmp/PolaroidVibe-preview.ipa`, khoảng 4.3 MB. Đây là bản device đã ký được đóng gói trong `Payload`, chưa phải bản Ad Hoc phát hành cho bạn bè.

## Tài khoản hiện tại

User xác nhận ngày 11/10/2026 đang dùng Apple miễn phí. Chưa upload: không có bản Ad Hoc cho thiết bị của bạn bè. Cần Apple Developer Program để đi theo luồng Ad Hoc dưới đây.

## Để bạn bè cài được

1. Xác nhận Apple Developer Program và team dùng để phát hành. Profile hiện tại có hạn 7 ngày; cần đổi sang team phù hợp để phân phối Ad Hoc.
2. Thu UDID iPhone của từng tester. Dùng trang lấy UDID từ mục UDID trên website Loadly, hoặc lấy bằng Xcode khi cắm máy vào Mac.
3. Đăng ký thiết bị trong Apple Developer, tạo profile Ad Hoc chứa các thiết bị đó.
4. Archive/export IPA bằng profile tương ứng. Không dùng bản Simulator.
5. Upload IPA lên Loadly bằng trình duyệt hoặc API. Nên đăng nhập để quản lý và thay bản; chọn mật khẩu hoặc lời mời khi chia sẻ nhóm thử.
6. Kiểm tra cài bằng link trên một máy tester đã đăng ký trước khi gửi rộng hơn.

Upload lên Loadly không thêm thiết bị vào profile và không gia hạn chữ ký Apple. Gửi bản hiện tại cho một iPhone chưa có trong profile sẽ không cài được.

## Tài liệu chính thức

- Loadly upload và API: https://loadly.io/doc/view/api
- Định dạng gói và lỗi upload: https://loadly.io/document/ios-most-common-upload-errors
- Thiết bị chưa có trong provisioning profile: https://loadly.io/document/ios-cant-install-an-app-on-a-device-things-to-check
- Apple Ad Hoc: https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices

API upload là `POST https://api.loadly.io/apiv2/app/upload`, multipart, gồm `_api_key`, `file`, tùy chọn `buildInstallType` (2: mật khẩu; 3: lời mời). Không đưa API key, provisioning profile, certificate hoặc IPA vào GitHub.
