# Project Structure (GetX)

```
lib/
├── main.dart
├── app/
│   ├── routes/          # AppRoutes, AppPages
│   └── bindings/        # Global bindings (future)
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── widgets/         # Shared widgets
├── data/
│   ├── models/
│   ├── providers/       # API / remote data
│   └── repositories/
└── modules/             # Feature modules (GetX pattern)
    ├── auth/            # ✅ Login (Phase 1)
    ├── splash/
    ├── home/            # Dashboard
    ├── attendance/
    ├── leave/
    ├── profile/
    ├── approvals/
    ├── payroll/
    ├── time_off/
    ├── late_checkin/
    ├── expense/
    ├── task/
    ├── announcement/
    ├── holiday/
    ├── directory/
    ├── shift/
    ├── chat/
    ├── notifications/
    ├── reports/
    └── settings/
```

Each module follows: `bindings/` · `controllers/` · `views/`
