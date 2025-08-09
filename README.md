## CrazyView

A lightweight, customizable WebView app built with Flutter.
-	저장된 메인 URL에서 시작 (SharedPreferences)
-	Deep Link로 외부 앱/브라우저에서 열기
-	상단 Home 아이콘으로 메인 URL로 즉시 이동
-	설정 화면에서 메인 URL 변경

---

### Features
-	Main URL 저장/로드
  -	기본값: https://quickdraw.withgoogle.com/
  -	키: main_url
-	Deep Link 지원 (crazyview://)
  -	crazyview://open → 마지막 URL 또는 메인 URL 열기
  -	crazyview://open?url=<ENCODED_URL> → 특정 URL 열기
  -	crazyview://settings → 설정 화면 열기
-	Home 버튼: 저장된 메인 URL로 이동

---

### Getting Started

```bash
# Flutter SDK 확인
flutter –version

# 의존성 설치
flutter pub get

# 실행
flutter run
# 또는 iOS 실기기 릴리즈
flutter run –release
```

---

### iOS Setup

ios/Runner/Info.plist에 URL Scheme 추가:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.crzhacko.crazyview</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>crazyview</string>
    </array>
  </dict>
</array>
```

HTTPS 정책을 느슨히 하려면(필요 시):

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoadsInWebContent</key>
  <true/>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

> Note: iOS는 .xcworkspace 로 열어 빌드하세요. 번들 ID 변경 후 Xcode → Signing & Capabilities에서 Team 재지정 필요할 수 있음.

---

### Android Setup

android/app/src/main/AndroidManifest.xml 의 <activity ...> 안에 인텐트 필터:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="crazyview" />
</intent-filter>
```

> 필요하면 <data android:host="open" />, <data android:host="settings" /> 등으로 세분화 가능.

---

### Deep Link Testing
- 앱 열기: crazyview://open
-	특정 URL: crazyview://open?url=https%3A%2F%2Fflutter.dev
-	설정 화면: crazyview://settings

#### iOS (Safari Console)

```js
location.href = ‘crazyview://open’;
location.href = ‘crazyview://open?url=’ + encodeURIComponent(‘https://flutter.dev’);
location.href = ‘crazyview://settings’;
```

#### Android (ADB)

```bash
adb shell am start -a android.intent.action.VIEW -d “crazyview://open”
adb shell am start -a android.intent.action.VIEW -d “crazyview://open?url=https%3A%2F%2Fflutter.dev”
adb shell am start -a android.intent.action.VIEW -d “crazyview://settings”
```

---

### App Icon (optional)

```yaml
dev_dependencies:
flutter_launcher_icons: ^0.13.1

flutter_icons:
android: true
ios: true
image_path: “assets/icon.png”
```

```bash
flutter pub get
dart run flutter_launcher_icons
```

---

GitHub 연동

```bash
# git 초기화
git init
git add .
git commit -m “feat: initial CrazyView”

# 깃허브 리포 생성 후 URL 등록
git branch -M main
git remote add origin https://github.com/<YOUR_ID>/<REPO_NAME>.git

# 푸시
git push -u origin main
```

---

### Troubleshooting
-	딥링크 수신 안 됨: iOS URL Types / Android intent-filter 확인, iOS는 실행 중/백그라운드 상태도 확인

---

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.