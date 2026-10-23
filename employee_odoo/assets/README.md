# Assets (optional)

Copy from your CRM app into `assets/images/`:

- `logo.png`
- `login_bg.png`
- `url.png`, `arrow_down.png`, `database.png`, `username.png`, `password.png`

Then register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/images/
```

Until assets are added, the login screen uses a gradient background, Material icon fallbacks, and a text logo.
