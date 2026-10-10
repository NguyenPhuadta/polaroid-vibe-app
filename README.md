# Polaroid Vibe App

Prototype và research cho app camera film iOS: chụp ảnh, preset instant, hiệu ứng in ảnh và gallery.

Hiện có công cụ thử preset trên trình duyệt; chưa có project iOS.

## Chạy prototype

```sh
cd film-preset-lab
python3 -m http.server 8780 --bind 127.0.0.1
```

Mở http://127.0.0.1:8780, chọn ảnh và so sánh trước/sau. Ảnh được xử lý tại trình duyệt. Preview có cạnh dài tối đa 1600 px; xuất PNG ở độ phân giải preview.

## Bộ preset đã chọn

- PictureFX Polaroid SX-70 Core — mặc định, màu 100%, texture 60%.
- G’MIC / Pat David Polaroid 669.
- G’MIC / Pat David PX-70.
- G’MIC / Pat David Time Zero Expired.

Grain, softness, vignette và color cast là lớp texture riêng có thể điều chỉnh. Các preset phong cảnh cũ nằm trong nhóm tham khảo.

## Kiểm tra

```sh
node film-preset-lab/verify.cjs
```

Xem [research, quyết định và attribution](film-preset-lab/README.md). LUT và ảnh mẫu có nguồn, giấy phép riêng; repo chưa cấp giấy phép chung. Quyền phân phối PictureFX LUT và ảnh mẫu trong sản phẩm cần làm rõ trước khi phát hành.

## Bước tiếp theo

Thiết kế Figma cho Camera, Preview, Gallery và Detail; sau đó xây app iOS và đối chiếu màu preview/export trên iPhone.
