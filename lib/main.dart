import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String kPrefsKeyMainUrl = 'main_url';

final FlutterLocalNotificationsPlugin _notifPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);
  await _notifPlugin.initialize(initSettings);

  if (Platform.isIOS) {
    await _notifPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}

Future<void> _showNotification(String title, String body) async {
  const androidDetails = AndroidNotificationDetails(
    'crazylab_notifications',
    'CrazyLab 알림',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const details =
      NotificationDetails(android: androidDetails, iOS: iosDetails);
  await _notifPlugin.show(
      0, title, body.isEmpty ? null : body, details);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a1a2e),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color(0xFF111827),
      ),
      home: const RootScreen(),
    );
  }
}

// 루트: URL 설정 여부에 따라 온보딩 or WebView 분기
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _loading = true;
  String _homeUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(kPrefsKeyMainUrl) ?? '';
    setState(() {
      _homeUrl = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_homeUrl.isEmpty) {
      return SetupScreen(
        onSaved: (url) => setState(() => _homeUrl = url),
      );
    }
    return WebViewScreen(
      homeUrl: _homeUrl,
      onHomeUrlChanged: (url) => setState(() => _homeUrl = url),
    );
  }
}

// 첫 실행 URL 설정 화면
class SetupScreen extends StatefulWidget {
  final ValueChanged<String> onSaved;

  const SetupScreen({super.key, required this.onSaved});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  String? _error;

  bool _isValidHttpUrl(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (!_isValidHttpUrl(text)) {
      setState(() => _error = 'https://... 형식으로 입력해 주세요.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsKeyMainUrl, text);
    widget.onSaved(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CrazyView',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '어드민 URL을 입력하세요.',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://admin.example.com',
                  hintStyle: TextStyle(color: Colors.white38),
                  errorText: _error,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('시작하기',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 메인 WebView 화면
class WebViewScreen extends StatefulWidget {
  final String homeUrl;
  final ValueChanged<String> onHomeUrlChanged;

  const WebViewScreen({
    super.key,
    required this.homeUrl,
    required this.onHomeUrlChanged,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _wv;
  late final AppLinks _appLinks;
  late String _homeUrl;
  bool _canGoBack = false;
  bool _isLoading = false;
  bool _awaitingAuth = false; // Google OAuth 완료 후 리로드 플래그
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _homeUrl = widget.homeUrl;
    _appLinks = AppLinks();

    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColorIfSupported()
      ..addJavaScriptChannel(
        'flutter_notification',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final title = data['title'] as String? ?? '새 알림';
            final body = data['body'] as String? ?? '';
            await _showNotification(title, body);
          } catch (e) {
            debugPrint('[Notification bridge] error: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (url) async {
            final canGoBack = await _wv.canGoBack();
            setState(() {
              _isLoading = false;
              _canGoBack = canGoBack;
            });
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == true) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (req) {
            final url = req.url;
            // Google OAuth - WKWebView에서 막히므로 SFSafariViewController로 열기
            if (url.contains('accounts.google.com')) {
              _awaitingAuth = true;
              launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
              return NavigationDecision.prevent;
            }
            if (url.startsWith('http')) return NavigationDecision.navigate;
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      );

    _loadHome();
    _initDeepLinks();
    WidgetsBinding.instance.addObserver(this);
  }

  // Google OAuth 완료 후 앱으로 돌아오면 WebView 리로드
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingAuth) {
      _awaitingAuth = false;
      _wv.reload();
    }
  }

  Future<void> _loadHome({bool clearCookies = false}) async {
    if (clearCookies) {
      await WebViewCookieManager().clearCookies();
    }
    await _wv.loadRequest(Uri.parse(_homeUrl));
  }

  void _initDeepLinks() async {
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) _handleDeepLink(initialUri.toString());

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri.toString()),
      onError: (err) => debugPrint('[DeepLink] error: $err'),
    );
  }

  void _handleDeepLink(String link) async {
    Uri uri;
    try {
      uri = Uri.parse(link);
    } catch (_) {
      return;
    }

    final host = uri.host;
    final path = uri.path;

    if (host == 'settings' || path.contains('settings')) {
      _openSettings();
      return;
    }

    if (host == 'open') {
      final newUrl = uri.queryParameters['url'];
      if (newUrl != null && newUrl.isNotEmpty) {
        await _wv.loadRequest(Uri.parse(newUrl));
      }
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(currentUrl: _homeUrl),
      ),
    );
    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefsKeyMainUrl, result);
      _homeUrl = result;
      widget.onHomeUrlChanged(result);
      await _loadHome(clearCookies: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _BackButton(
          enabled: _canGoBack,
          onTap: () async {
            try {
              await _wv.runJavaScript('history.back();');
            } catch (_) {}
          },
        ),
        title: GestureDetector(
          onTap: _loadHome,
          child: const Text(
            'CrazyView',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: '설정',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _wv),
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}

// 뒤로가기 버튼 위젯
class _BackButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _BackButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.chevron_left,
        size: 28,
        color: enabled ? Colors.white : Colors.white24,
      ),
      tooltip: '뒤로',
      onPressed: enabled ? onTap : null,
    );
  }
}

// URL 설정 페이지
class SettingsPage extends StatefulWidget {
  final String currentUrl;

  const SettingsPage({super.key, required this.currentUrl});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUrl);
  }

  bool _isValidHttpUrl(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('설정', style: TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '어드민 URL',
              style: TextStyle(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://admin.example.com',
                hintStyle: TextStyle(color: Colors.white38),
                errorText: _error,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white60),
                  borderRadius: BorderRadius.circular(8),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (!_isValidHttpUrl(text)) {
                    setState(() => _error = 'https://... 형식으로 입력해 주세요.');
                    return;
                  }
                  Navigator.pop(context, text);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('저장',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _BgExt on WebViewController {
  void setBackgroundColorIfSupported() {
    if (Platform.isIOS || Platform.isAndroid) {
      setBackgroundColor(Colors.white);
    }
  }
}
