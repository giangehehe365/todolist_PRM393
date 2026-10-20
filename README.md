# TodoList — Assignment 2

Ứng dụng Flutter quản lý công việc, dùng StatefulWidget và setState.

## Chức năng

- Login với Email / Username và Password, kiểm tra trường bắt buộc.
- SharedPreferences lưu tên đăng nhập để tự khôi phục phiên khi mở lại app.
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

## Đăng nhập cục bộ theo đề bài

Nhập tên đăng nhập/email và mật khẩu bất kỳ, miễn không để trống.
Đây là mô phỏng login phục vụ bài tập, chưa có đăng ký hay xác thực mật khẩu.
Mật khẩu không được lưu. Tên đăng nhập được trim và chuyển chữ thường;
đăng nhập lại cùng tên sẽ đọc lại danh sách của tên đó.
Tên khác có danh sách riêng. Cơ chế này không cung cấp bảo mật tài khoản thực tế.

Công việc được lưu trong `todo_v2.db`, bảng `tasks`, schema version 1.
Ngày tạo được giữ nguyên khi sửa và thay đổi trạng thái.
Xóa dữ liệu ứng dụng hoặc gỡ cài đặt có thể làm mất cơ sở dữ liệu và phiên.
Dữ liệu mẫu trong bài 1 không tự thêm lại mỗi lần mở app.

## Cấu trúc

- `lib/main.dart`: khởi động và giao diện quản lý công việc.
- `lib/screens/session_gate.dart`: khôi phục phiên, Login và chuyển màn hình.
- `lib/data/session_store.dart`: đọc/lưu/xóa phiên SharedPreferences.
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
