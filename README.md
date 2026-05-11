# Alpha Mini Family App

Ứng dụng Flutter quản lý người nhà qua robot Alpha Mini.

## Tính năng

- 🔐 **Đăng nhập** - Chỉ tài khoản `FAMILYMEMBER` được phép truy cập
- 👴 **Quản lý Elderly Profile** - Thêm, xem danh sách người nhà
- ⏰ **Reminder** - Thêm nhắc nhở, xem trạng thái xác nhận, cảnh báo chưa xác nhận
- 🤖 **Exercise** - Thêm bài tập động tác, gửi lệnh đến robot Alpha Mini

## Cài đặt

### Yêu cầu
- Flutter SDK >= 3.10.0
- Dart >= 3.0.0
- Android Studio / VS Code

### Chạy app

```bash
cd alpha_mini_app
flutter pub get
flutter run
```

## Cấu trúc dự án

```
lib/
├── main.dart                    # Entry point
├── models/
│   └── models.dart              # User, ElderlyProfile, Reminder, Exercise
├── services/
│   ├── api_service.dart         # HTTP calls đến API
│   └── auth_provider.dart       # Auth state management
├── screens/
│   ├── splash_screen.dart       # Splash + auto-login
│   ├── login_screen.dart        # Đăng nhập
│   ├── home_screen.dart         # Danh sách người nhà
│   ├── add_elderly_screen.dart  # Thêm người nhà
│   ├── elderly_detail_screen.dart # Chi tiết + tab Reminder/Exercise
│   ├── reminders_screen.dart    # Quản lý Reminder + Alert
│   └── exercises_screen.dart    # Quản lý Exercise + Gửi robot
└── utils/
    ├── constants.dart           # API endpoints
    └── theme.dart               # App theme & colors
```

## Kết nối API

API base URL: `https://sep490-be-3.onrender.com`

### Endpoints được dùng

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/auth/login` | Đăng nhập |
| GET | `/api/v1/elderly-profiles` | Danh sách người nhà |
| POST | `/api/v1/elderly-profiles` | Thêm người nhà |
| GET | `/api/v1/reminders?elderlyProfileId={id}` | Reminders của người nhà |
| POST | `/api/v1/reminders` | Thêm reminder |
| DELETE | `/api/v1/reminders/{id}` | Xóa reminder |
| GET | `/api/v1/exercises?elderlyProfileId={id}` | Bài tập của người nhà |
| POST | `/api/v1/exercises` | Thêm bài tập |
| DELETE | `/api/v1/exercises/{id}` | Xóa bài tập |
| POST | `/api/v1/exercises/{id}/send-to-robot` | Gửi bài tập đến robot |

## ⚠️ Điều chỉnh nếu API có cấu trúc khác

Nếu API trả về format khác với dự kiến, điều chỉnh trong:

1. **Login response** - `auth_provider.dart` dòng 38-48:
   ```dart
   final token = response['token'] ?? response['accessToken'] ?? ...
   final role = userData['role'] ?? ...
   ```

2. **List response** - `api_service.dart` hàm `_handleListResponse`:
   ```dart
   if (decoded is Map && decoded.containsKey('data')) { ... }
   ```

3. **Field names** - Trong `models/models.dart`, mỗi model có fallback:
   ```dart
   json['fullName'] ?? json['full_name'] ?? ''
   ```

## Thêm tính năng

### Notification cho reminder chưa xác nhận
Thêm package `flutter_local_notifications` và gọi trong `reminders_screen.dart`:
```dart
void _checkUnconfirmed(List<Reminder> list) {
  // Đã có alert dialog, thêm local notification ở đây
}
```

### Polling tự động
Thêm Timer trong `RemindersScreen.initState()`:
```dart
Timer.periodic(Duration(minutes: 5), (_) => _load());
```
