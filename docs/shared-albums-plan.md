# Album chung — mỗi người một cuộn film

Ngày ghi nhận: 10/10/2026.

**Trạng thái: lưu ý tưởng và plan, tạm hoãn triển khai.**

Theo quyết định mới nhất của người dùng, ưu tiên làm UI trước. Chờ người dùng gửi mẫu/reference để build; chưa triển khai album chung, backend, mời bạn hoặc cấp lượt. Các quy tắc dưới đây là đề xuất nghiên cứu, chưa phải quyết định sản phẩm đã được duyệt.

## Ý tưởng người dùng

Chủ album tạo một album, phát cho từng người bạn một số lượt chụp nhất định. Ảnh bạn chụp tự liên kết vào album đã tạo, có thông tin người chụp.

Ví dụ: album “Đà Lạt cuối tuần”, An 12 tấm, Bình 12 tấm, Chi 6 tấm. Mỗi người có hạn mức riêng; chủ album quản lý ảnh, thành viên và lượt.

## Nghiên cứu tham khảo

- [POV — thông tin nhà phát triển trên App Store](https://apps.apple.com/us/app/pov-disposable-camera-events/id1636032890): mời bằng link/QR, giới hạn số ảnh mỗi khách, chọn thời điểm hiện album, khách không cần tải app.
- [Lense — FAQ](https://lense.app/faq): khách mở link, nhập tên và chụp; album chung, tùy chọn hiện ngay/hiện sau/riêng tư; hỗ trợ giữ ảnh offline và gửi khi có mạng sau khi đã tham gia.

## Luồng đề xuất

### Chủ album

1. Tạo album: tên, bìa, thời gian bắt đầu/kết thúc chụp.
2. Chọn một trong 4 preset có sẵn, áp chung cho album.
3. Thêm bạn và cấp lượt riêng, đề xuất mặc định 12 tấm/người.
4. Tạo link mời riêng cho từng người, gửi qua share sheet.
5. Theo dõi ai đã tham gia, số lượt đã dùng, ảnh đang gửi.
6. Cấp thêm lượt, thu hồi quyền chụp hoặc đóng album.

Link riêng phù hợp cấp lượt từng người. Một QR chung cho nhóm cần thêm nhận diện hoặc duyệt thành viên để tránh tạo nhiều suất.

### Người bạn

Mở lời mời → nhận suất chụp → camera của album → chụp → ảnh tự gửi vào album.

Camera hiện rõ tên album, preset và số lượt còn lại, ví dụ “Còn 8/12 tấm”. Sau khi chụp phân biệt trạng thái đã lưu local, đang gửi, đã vào album và gửi lỗi. Hết lượt vẫn được xem album nhưng không được chụp tiếp.

Đề xuất chỉ nhận ảnh chụp bằng camera của album trong bản đầu; nhập ảnh cũ là tùy chọn sau.

## Quy tắc lượt chụp đề xuất

| Tình huống | Hành vi |
|---|---|
| Mở lại link/thoát rồi vào lại | Dùng suất cũ, không nhận thêm lượt |
| Chụp lỗi, không tạo được ảnh | Không mất lượt |
| Chụp thành công nhưng gửi lỗi | Giữ ảnh local, gửi lại cùng mã ảnh, không trừ thêm |
| Xóa ảnh đã chụp | Không hoàn lượt |
| Đổi máy/mất phiên | Khôi phục quyền vào suất cũ, giữ số lượt đã dùng |
| Chủ album cấp thêm | Tăng hạn mức người đó |
| Album đóng khi ảnh đang gửi | Hoàn tất ảnh được cấp lượt trước lúc đóng |
| Nhiều album | Camera luôn chỉ rõ album đang nhận ảnh |

Bộ đếm và quyền phải được server thực thi, không chỉ lưu trên máy. Cần ngăn vượt lượt khi dùng nhiều máy hoặc yêu cầu đồng thời. Link lời mời là quyền truy cập cần có hạn dùng, thu hồi và cơ chế nhận suất; chưa chốt phương thức nhận diện khách.

## Xem album

Đề xuất bản đầu: ảnh hiện sau khi gửi thành công, thành viên được xem album chung; chủ album có quyền ẩn ảnh.

Giai đoạn sau: “Tráng film cùng nhau”, ẩn ảnh tới giờ mở album. Nếu làm, phải khóa quyền đọc/tải ảnh ở server, không chỉ ẩn UI.

## Các màn cần thêm

- Albums: album đã tạo và album được mời.
- Tạo album: tên, preset, thời gian, lượt mặc định.
- Album detail: ảnh chung, thành viên, tiến độ.
- Phát lượt: lời mời, hạn mức từng người, cấp thêm.
- Nhận lời mời: tên album, chủ album, suất chụp.
- Camera trong album: đích gửi, bộ đếm, trạng thái gửi.

Gallery cá nhân hiện tại tiếp tục giữ ảnh riêng. Camera mở từ album có đích gửi cụ thể.

## Plan triển khai đề xuất — chưa bắt đầu

| Bước | Phạm vi | Tiêu chí |
|---|---|---|
| A: Prototype luồng | Album/lời mời/cấp lượt/hết lượt bằng dữ liệu giả | Test UX trên một iPhone |
| B: Pilot nhiều máy | Nhận diện phiên, backend, kho ảnh cloud, lượt, retry | 2–3 iPhone chụp cùng album; không vượt lượt/trùng ảnh |
| C: Khách không cài app | Camera web, cùng backend/album/suất | iPhone và Android tham gia từ link |
| D: Trải nghiệm film | Reveal hẹn giờ, thông báo, offline đầy đủ | Chụp và mở album cùng nhau ổn định |

## Phác thảo kỹ thuật

- Dữ liệu: album, thành viên, lời mời, suất chụp và ảnh; kho ảnh riêng tư.
- Server giữ một lượt cho mã ảnh trước khi chụp; finalize sau khi upload hợp lệ. Request lặp dùng cùng mã, không lưu/trừ hai lần.
- Bản đầu cần mạng để nhận lượt. Mất mạng sau khi chụp: lưu ảnh và trạng thái local, gửi lại khi có kết nối.
- Chụp hoàn toàn offline cần cơ chế cấp vé chụp trước và đối soát; để sau.
- Giữ riêng quyền chủ album/khách, upload/đọc ảnh, đóng album/thu hồi lời mời. Chưa chọn nhà cung cấp backend.
- Trước pilot chia sẻ, rà soát quyền phân phối LUT/ảnh mẫu đang dùng trong prototype local.

## Quyết định còn mở

1. Khách cần cài app iOS hay dùng camera web ngay từ đầu?
2. Ảnh hiện ngay hay chỉ mở sau?
3. Preset do chủ album khóa hay mỗi người tự chọn?
4. Cách nhận diện/khôi phục khách, xử lý chuyển tiếp lời mời?
5. Thời hạn giữ ảnh, chất lượng xuất và giới hạn dung lượng?

## Ưu tiên hiện tại

**UI trước, album chung sau.** Đợi mẫu/reference từ người dùng. Không tự bắt đầu các bước A–D của tính năng album chung khi chưa có yêu cầu tiếp tục.
