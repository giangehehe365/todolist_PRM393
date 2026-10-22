# TodoList — Assignment 2

Ứng dụng Flutter quản lý công việc, dùng StatefulWidget và setState.

## Chức năng

- Đăng ký và Login với Email / Username và Password, xác thực bằng SQLite.
- SQLite xác thực tài khoản, SharedPreferences lưu token để tự khôi phục phiên khi mở lại app.
- Logout xóa phiên và quay về Login, không xóa công việc.
- SQLite lưu ID tự tăng, tên người dùng, tiêu đề, nội dung, hạn công việc,
  độ khó, trạng thái hoàn thành và thời điểm tạo.
- Thêm, đọc, sửa, đánh dấu hoàn thành/chưa hoàn thành và xóa công việc.
- Tìm kiếm, lọc trạng thái/độ khó, sắp xếp và thống kê.
- Dữ liệu chỉ thay đổi trên màn hình sau khi ghi SQLite thành công;
  lỗi tải có nút thử lại, lỗi ghi giữ nguyên dữ liệu và thông báo lỗi.

## Chạy

```sh
flutter pub get
flutter run
```

Chọn thiết bị Android hoặc Windows. SQLite trên web chưa được cấu hình.
Trên Windows, bật Settings > System > For developers > Developer Mode nếu Flutter
báo “Building with plugins requires symlink support”, rồi chạy lại `flutter pub get`.
Windows desktop cần bộ công cụ Visual Studio cho Flutter.

## Đăng nhập bằng SQLite

- Chọn **Chưa có tài khoản? Đăng ký**, nhập tên đăng nhập/email, mật khẩu ít nhất 8 ký tự và xác nhận mật khẩu.
- Tên đăng nhập được trim và chuyển chữ thường; không thể đăng ký trùng tên.
- Đăng nhập chỉ thành công khi tài khoản tồn tại và mật khẩu khớp.
- Bảng `users` lưu mật khẩu bằng PBKDF2-HMAC-SHA256 (600.000 vòng) cùng salt ngẫu nhiên riêng; không lưu mật khẩu gốc.
- Bảng `sessions` lưu token ngẫu nhiên có hạn 30 ngày. SharedPreferences chỉ giữ token để khôi phục phiên; logout thu hồi token.
- Phiên đăng nhập mô phỏng cũ không còn được chấp nhận. Hãy đăng ký tài khoản để sử dụng.
- Đây là tài khoản cục bộ trên thiết bị, chưa có đồng bộ hoặc khôi phục mật khẩu qua máy chủ.

Công việc được lưu trong `todo_v2.db`, bảng `tasks`, schema version 2.
Nâng cấp từ schema 1 tự tạo bảng tài khoản và phiên, giữ nguyên công việc hiện có.
Dữ liệu công việc cũ vẫn gắn với tên đăng nhập trước đây; đăng ký cùng tên sẽ đọc lại danh sách đó.
Ngày tạo được giữ nguyên khi sửa và thay đổi trạng thái.
Xóa dữ liệu ứng dụng hoặc gỡ cài đặt có thể làm mất cơ sở dữ liệu và phiên.

## Cấu trúc

- `lib/main.dart`: khởi động và giao diện quản lý công việc.
- `lib/screens/session_gate.dart`: khôi phục phiên, Login và chuyển màn hình.
- `lib/data/session_store.dart`: đăng ký, xác thực mật khẩu, quản lý token phiên SQLite và SharedPreferences.
- `lib/data/task_database.dart`: SQLite schema và CRUD theo người dùng.
- `lib/models/task.dart`: Task và chuyển đổi dữ liệu SQLite.

## Kiểm tra

```sh
flutter analyze
flutter test
```

Widget tests kiểm tra login, khôi phục phiên, logout, CRUD, bộ lọc và lỗi ghi.
Database test ghi file SQLite thật, đóng/mở lại, kiểm tra dữ liệu, trạng thái,
xóa và giới hạn truy vấn theo tên người dùng.

Thư viện: [sqflite](https://pub.dev/packages/sqflite),
[sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) cho desktop,
[shared_preferences](https://pub.dev/packages/shared_preferences) cho phiên.
