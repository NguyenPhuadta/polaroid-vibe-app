# Film Preset Lab

Công cụ thử màu local cho app camera film iOS. Không cần dependency; chạy từ thư mục này:

```sh
python3 -m http.server 8780 --bind 127.0.0.1
```

Mở http://127.0.0.1:8780. Chọn ảnh, preset, cường độ LUT và lớp máy film dùng một lần. Có thanh trước/sau và xuất PNG. Ảnh được xử lý trong trình duyệt; cạnh dài preview tối đa 1600 px. Chưa hỗ trợ giải mã RAW/HEIC riêng.

## Bản chỉnh theo reference người dùng

Alpine Vintage là công thức màu mới, độc lập với bốn LUT t3mujinpack. Reference có trời teal, tuyết kem ấm, cây/đất olive-nâu, bóng tối sâu, grain và vật thể gần máy tạo khung tối. Chỉ từ ảnh này không thể xác định film stock hoặc suy ra một phép biến đổi duy nhất vì không có ảnh gốc cùng cảnh.

Công thức dùng điều chỉnh hue/saturation theo dải màu, tone curve ấm và grain/nét dịu/vignette có seed ổn định. Không phân đoạn sky: vật thể xanh dương khác cũng bị đổi sang teal. Không chồng lại màu lên chính ảnh reference đã grade. Không tự thêm khung cửa hoặc silhouette. Chưa đo mức độ khớp với reference trên ảnh gốc iPhone; ảnh mẫu hiện tại thiếu bầu trời.

Mặc định: Alpine Vintage 90%, texture 75%. Test bổ sung xác nhận HSV round trip, cường độ 0 giữ nguyên màu, output hữu hạn trong 0–255, xanh dương chuyển teal và trắng chuyển ấm.

## Kết quả research

Đối chiếu ngày 10/10/2026. Đây là shortlist, chưa phải benchmark trên bộ ảnh iPhone hoặc so với bản scan film thật.

### t3mujinpack: nguồn dùng cho prototype

[Repository](https://github.com/t3mujinpack/t3mujinpack), [LUT PNG](https://github.com/t3mujinpack/t3mujinpack/tree/master/haldcluts), [MIT License](https://github.com/t3mujinpack/t3mujinpack/blob/master/LICENSE.txt).

Bộ preset chủ yếu điều chỉnh đường cong màu Lab. Không có bằng chứng từ tài liệu đã đọc rằng nó được hiệu chuẩn bằng cặp ảnh digital/film cùng cảnh. Phù hợp thử chất màu, không nên gọi là mô phỏng chính xác hóa học film.

LUT tải về là PNG 1728 × 1728, tương ứng Hald level 12 và cube 144³. Kiểm tra bằng sips cho thấy Velvia PNG có profile sRGB. Bản test đọc LUT qua canvas sRGB và nội suy trilinear; chưa đối chiếu output với Darktable.

[Script tạo LUT](https://github.com/t3mujinpack/t3mujinpack/blob/master/haldcluts/create_haldcluts_from_styles.sh) bake style bằng darktable-cli, nhưng file hiện chỉ chứa một lệnh Astia. Không nên coi nó là pipeline tái tạo hoàn chỉnh mọi LUT hoặc mặc định LUT có sẵn đồng bộ với style mới nhất.

[Bài tác giả 02/04/2025](https://t3mujinpack.github.io/2025/04/update-on-t3mujinpack-and-next/) xác nhận vẫn duy trì nhưng phát hành bị chậm. Nên pin revision và checksum khi tích hợp thật.

### Các nguồn khác

- [RawTherapee Film Simulation Collection](https://rawpedia.pixls.us/film_simulation/): nhiều biến thể, tiện khám phá màu. [README](https://github.com/cedeber/hald-clut/blob/master/HaldCLUT/Film%20Simulation/README.txt) ghi CC BY-SA 4.0. [Pat David](https://patdavid.net/2013/08/film-emulation-presets-in-gmic-gimp/) mô tả các emulation ban đầu là diễn giải sáng tạo từ ví dụ, không chính xác tuyệt đối, chưa gồm grain/vignette.
- [Spectral Film LUT](https://github.com/JanLohse/spectral_film_lut): generator MIT dùng dữ liệu datasheet và mô phỏng nhiều bước; có Velvia, Provia, Ektar và Portra. [Tài liệu](https://janlohse.github.io/spectral_film_lut/) thừa nhận dữ liệu thiếu và các giả định interlayer. Có thể bake LUT đúng input màu cho app; đáng nghiên cứu tiếp nếu muốn kiểm soát film + giấy in.
- [spektrafilm](https://github.com/andreavolpato/spektrafilm): engine spectral mạnh hơn, code GPLv3; profiles/LUT có giấy phép riêng. README còn câu về custom no-resale, trong khi [file giấy phép hiện tại](https://github.com/andreavolpato/spektrafilm/blob/main/SPEKTRAFILM_LICENSE.txt) ghi CC BY-SA 4.0 và phân biệt yêu cầu pháp lý với mong muốn tác giả. Cần pin phiên bản và làm rõ trước khi đóng gói sản phẩm; không xếp vào luồng MIT đơn giản.
- [pyrocat101/Fujifilm-LUTs](https://github.com/pyrocat101/Fujifilm-LUTs): chuyển LUT Fujifilm chính thức sang nhiều color space. Bản Apple Log dành cho input log video, không phải LUT áp trực tiếp lên JPEG/HEIC. Chưa thấy LICENSE trong cây file đã kiểm tra; không coi việc repo public là quyền phân phối vào app.

## Chọn look cho phong cảnh

- Velvia: ứng viên nổi bật cho phong cảnh rực. [Fujifilm](https://www.fujifilm-x.com/global/products/film-simulation/velvia/) định hướng trời rộng, cây xanh và landscape. Ảnh mẫu t3mujinpack quan sát thấy xanh sâu hơn và vùng tối đậm hơn; không có trời trong ảnh này để đánh giá chuyển màu bầu trời.
- Ektar: ứng viên cho núi đá và cảnh nắng. [Kodak](https://www.kodakprofessional.com/photographers/film/color/filme-kodak-professional-ektar-100/530) định hướng nature/travel/outdoor, màu đậm và nét cao.
- Provia: ứng viên mặc định cân bằng; [Fujifilm](https://www.fujifilm.com/us/en/business/professional-photography/film/provia-100f) mô tả saturation/contrast vừa và dùng cho landscape.
- Portra: lựa chọn bổ sung để thử màu dịu. Ảnh mẫu tác giả là chân dung, không đủ chứng minh đẹp trên núi có sương; bản after cũng không mặc định đen bạc/pastel.

Đặc tính film thật hoặc film simulation hãng không đảm bảo preset cộng đồng cùng tên cho output giống nhau.

## Chất máy film dùng một lần

Theo lựa chọn người dùng, thêm lớp sáng tạo riêng: grain luminance/chroma có seed ổn định, softness nhẹ, màu ấm ở vùng sáng và cyan/green ở vùng tối, nâng black point và vignette. Không mô phỏng camera hoặc film stock cụ thể. Chưa có light leak, halation, bụi/xước, lỗi flash hoặc khung in.

## Kiểm tra đã thực hiện

`node verify.cjs`: Hald dimension, 1.000 màu qua identity LUT, endpoints RGB, LUT hoán vị kênh; bypass texture, deterministic grain và alpha.

Browser QA: đổi 4 preset; cường độ và before/after; bật lớp disposable; chọn ảnh từ máy; xuất PNG thành công 1200 × 800. Render trên ảnh mẫu khoảng 50–100 ms ở trình duyệt đang chạy; không phải benchmark iOS.

Khi chốt màu, cần test cùng bộ ảnh trời xanh, mây trắng, hoàng hôn, núi tối, sương và người trong cảnh. Kiểm tra banding, clipping và màu trung tính, sau đó đối chiếu trên iPhone. iOS có [CIColorCubeWithColorSpace](https://developer.apple.com/documentation/coreimage/cicolorcubewithcolorspace); phải khai báo color space đúng, không giả định chuyển PNG sang float là đủ.

## Attribution

LUT của João Almeida / t3mujinpack, MIT; bản giấy phép kèm trong assets. [Ảnh mẫu](https://t3mujinpack.github.io/samples/Velvia50_before.webp) lấy từ trang tác giả để đối chiếu local; chưa xác minh giấy phép tái phân phối ảnh mẫu cho sản phẩm. Không dùng ảnh này làm asset ship trong app nếu chưa có quyền phù hợp.

## Quyết định người dùng — 10/10/2026

G’MIC / Pat David Instant được người dùng đánh giá phù hợp và chọn giữ trong shortlist preset Polaroid cho app. Ưu tiên thử 669 và PX-70; chưa chốt preset sản phẩm.

Nguồn: https://gmic.eu/color_presets/instant_consumer_sample_9.html và https://gmic.eu/color_presets/instant_pro_sample_9.html. Collection gốc: https://github.com/cedeber/hald-clut/blob/master/HaldCLUT/Film%20Simulation/README.txt (CC BY-SA 4.0).

## PictureFX SX-70 — bản thử local

Theo yêu cầu người dùng, tải PictureFX-Polaroid-SX-70.zip từ https://picturefx.itch.io/picturefx-polaroid-sx-70-the-core-lut và dùng file PictureFX-Polaroid-SX-70-Core-Lut.cube gốc, cube 64³, domain 0–1, thứ tự red-fastest. Header ghi Marc Open Source Photography và TITLE PictureFX-Polaroid-SX-70-Shoebox-Prints. File lưu tại assets/picturefx-sx70.cube.

Đọc CUBE thành Float32Array (giá trị float giữ nguyên, scale 255), trilinear bằng sampler hiện có. Mặc định SX-70 100%, không thêm lớp disposable. Có thể bật texture riêng để thử nhưng texture đó là lớp sáng tạo của prototype, không phải thành phần LUT PictureFX.

Trang phân phối ghi “Free to use. Free to tweak. Credit optional, but always appreciated.” Gói ZIP không có LICENSE riêng. Chỉ tích hợp vào prototype local theo yêu cầu, chưa xác nhận quyền phân phối LUT trong sản phẩm.

## Bộ template được chọn — 10/10/2026

Người dùng chọn PictureFX SX-70 sau khi thử và yêu cầu thêm chất film, cùng các preset G’MIC. Bộ chính gồm đúng 4 template: PictureFX SX-70 Core, G’MIC/Pat David Polaroid 669, PX-70, Time Zero Expired. 5 preset cũ giữ ở nhóm tham khảo, không thuộc bộ chính.

Mặc định: SX-70 100%, texture 60% bật. Grain, softness, vignette và color cast hiện là lớp sáng tạo chung của prototype; có thể tắt hoặc chỉnh riêng. Đổi template giữ nguyên mức màu/texture để so sánh cùng điều kiện. Attribution G’MIC lưu tại assets/ATTRIBUTION-gmic.txt.

QA bộ instant: cả 4 template render thành công trên browser (1200×800, LUT 64³), giữ texture 60% khi đổi preset; kiểm tra thuần bằng node verify.cjs đạt. Preview: instant-templates-preview.jpg.
