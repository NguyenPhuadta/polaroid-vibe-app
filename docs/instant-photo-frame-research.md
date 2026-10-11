# Khung ảnh instant — research cho màn kết quả

Ngày: 2026-10-11. Chỉ research/đề xuất; chưa đổi code/UI hoặc format dữ liệu.

## Yêu cầu

Ảnh sau khi chụp và lưu phải có khung giấy kiểu ảnh tham chiếu của user. User đang vẽ lại màn kết quả. Giữ ba ratio vùng ảnh đã thống nhất: ngang 99:62, vuông 1:1, dọc 23:31. Ratio khung ngoài khác ratio vùng ảnh.

## Nguồn chính hãng

- Polaroid Support: https://support.polaroid.com/hc/en-us/articles/115012363647-What-are-Polaroid-photo-dimensions
  SX-70/600/i-Type toàn tấm rộng 88.47 × cao 107.52 mm; vùng ảnh gần vuông 76.801 × 78.94 mm theo số đo chính xác của trang. Không áp ratio khung ngoài này lên ảnh dọc/ngang.
- Fujifilm Mini: https://www.instaxus.com/film/mini-white-film/
  Toàn tấm rộng 54 × cao 86 mm; vùng ảnh rộng 46 × cao 62 mm. Ratio vùng ảnh 23:31 đúng với lựa chọn dọc của app.
- Fujifilm Square: https://www.instax.com/squareformat/en/
  Toàn tấm rộng 72 × cao 86 mm; vùng ảnh 62 × 62 mm.
- Fujifilm Wide: https://www.instaxus.com/film/wide-white-film/
  Toàn tấm rộng 108 × cao 86 mm; vùng ảnh rộng 99 × cao 62 mm, đúng ratio ngang app.
- Fujifilm Film: https://www.instax.com/film/
  Có ba họ Mini/Square/Wide và các màu khung khác nhau.

## Phân tích ảnh tham chiếu

Quan sát trực tiếp ảnh user gửi: giấy trắng hơi xám, texture sợi giấy rất nhẹ; ảnh nằm trong một cửa sổ có bo góc rất nhỏ; viền đáy dày hơn viền trên, viền trên cũng dày hơn hai bên; đường viền cửa sổ tối nhẹ; mép giấy hơi nổi, bóng đổ mềm xuống dưới. Vết bụi/xước chỉ là phong cách của mẫu, không cần mặc định làm bẩn mọi ảnh.

Phân tách khi thiết kế: (1) thân giấy + texture riêng; (2) ảnh đã áp preset, giữ đúng ratio; (3) mép cửa sổ mảnh để tạo cảm giác ảnh lõm; (4) bóng đổ của cả tấm trên nền màn hình. LUT/grain ảnh không áp vào màu giấy. Bóng của cả tấm thuộc presentation UI; đề xuất bản lưu chỉ chứa giấy + ảnh, không chứa nền màn hoặc bóng đổ ngoài tấm.

## Đề xuất kích thước dễ vẽ

Đây là bộ thông số thiết kế riêng của app, lấy cảm hứng từ instant film, không phải số đo sản xuất chính hãng hay phép đo chính xác của ảnh tham chiếu.

Với khung ngoài rộng W: trái/phải/trên = 0.06W; đáy = 0.20W. Vùng ảnh rộng 0.88W. Khung cao = chiều cao vùng ảnh + 0.26W. Mọi thông số scale theo W, không giữ padding pixel cố định khi export lớn.

Ví dụ khung ngoài W=350 px trên Figma: padding trái/phải/trên 21 px, đáy 70 px; vùng ảnh rộng 308 px.

| Ratio ảnh | Vùng ảnh (W × H) | Khung giấy (W × H) |
|---|---|---|
| Ngang 99:62 | 308 × 192.89 | 350 × 283.89 |
| Vuông 1:1 | 308 × 308 | 350 × 399 |
| Dọc 23:31 | 308 × 415.13 | 350 × 506.13 |

Màu giấy đề xuất #F5F3EE; bo ngoài 2–4 px, bo cửa sổ 1–2 px ở W350. Texture giấy opacity 2–4% là điểm bắt đầu để thử, chưa chốt. Để viền đáy trống trước, caption/date theo design user sau. Nếu muốn giống mẫu hơn, tăng viền trên riêng; bảng trên ưu tiên bộ khung gọn đồng nhất giữa ba ratio.

## Hiện trạng và hướng build sau

PrintCard trong ios/PolaroidVibe/PolaroidVibeApp.swift đang tạo khung UI bằng padding/background/shadow. PhotoStore.save lưu JPEG ảnh đã render, chưa có khung. DetailScreen chia sẻ UIImage lưu đó nên export cũng chưa có khung.

Đề xuất lưu ảnh đã áp preset riêng và cấu hình khung riêng (style/version/ratio/caption nếu có), tạo bản ghép giấy + ảnh cho lưu vào Photos/chia sẻ. Giữ dữ liệu ảnh không khung nội bộ để đổi thiết kế về sau, nhưng kết quả user nhận được phải có khung. Preview/Gallery/Detail/export dùng cùng một định nghĩa geometry để không bị lệch hay bọc viền hai lần. Ảnh cũ cần chính sách hiển thị khi build, không tự sửa hàng loạt ở giai đoạn research.

Chờ Figma màn kết quả mới trước khi triển khai. Không thay Camera UI, không cài bản mới trong lượt research này.


## Demo native trong app (2026-10-11)

Theo yêu cầu user đã triển khai bản thử, không chạy tests. InstantFrame dùng UIGraphicsImageRenderer ghép giấy #F5F3EE, texture noise deterministic nhẹ, cửa sổ bo nhỏ và mép tối. Geometry viền 6% trái/phải/trên và 20% đáy giữ nguyên ba ratio. Khung xuất giới hạn chiều cao 2200 px, scale 1. Preview dùng ảnh ghép; PhotoStore lưu chính JPEG có khung, metadata frameVersion=1 để Gallery/Detail không bọc hai lần. Ảnh cũ được bọc khung khi đọc để hiển thị/chia sẻ, file cũ không bị ghi lại. Bóng đổ chỉ nằm trên UI; viền đáy chưa có caption. Preview tăng chiều rộng hiển thị bằng cách giảm horizontal padding xuống 24 pt. Camera live preview vẫn xử lý ảnh không khung.

Device BUILD SUCCEEDED. Không chạy unit/UI tests theo yêu cầu user. Đây là demo chất liệu, màn kết quả còn chờ Figma mới.
