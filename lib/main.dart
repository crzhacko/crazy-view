import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String kPrefsKeyMainUrl = 'main_url';
const String kDefaultUrl = 'https://quickdraw.withgoogle.com/'; // 원하는 기본값

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _wv;
  String _status = 'Initializing...';
  String _currentUrl = kDefaultUrl;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // macOS에선 미구현이라 호출 금지
      ..setBackgroundColorIfSupported()
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[WV] start $url');
            setState(() => _status = 'Loading...');
          },
          onPageFinished: (url) {
            debugPrint('[WV] finished $url');
            setState(() => _status = 'WebView');
          },
          onWebResourceError: (err) {
            debugPrint(
              '[WV][ERROR] code=${err.errorCode} '
              'type=${err.errorType} '
              'desc=${err.description} '
              'main=${err.isForMainFrame}',
            );
            setState(() => _status = 'Error: ${err.errorCode}');
          },
          onNavigationRequest: (req) {
            final url = req.url;
            debugPrint('[WV] nav $url');
            if (url.startsWith('http')) return NavigationDecision.navigate;
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      );

    // _initUrlAndLoad();
    _bootstrap();
  }

  // Future<void> _initUrlAndLoad() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final saved = prefs.getString(kPrefsKeyMainUrl);
  //   _currentUrl = (saved != null && saved.isNotEmpty) ? saved : kDefaultUrl;
  //   await _wv.loadRequest(Uri.parse(_currentUrl));
  //   setState(() => _status = 'Loaded');
  // }

  Future<void> _bootstrap() async {
    // 1) 초기 URL 로드 (저장된 값 or 기본값)
    final prefs = await SharedPreferences.getInstance();
    _currentUrl = prefs.getString(kPrefsKeyMainUrl) ?? kDefaultUrl;
    await _wv.loadRequest(Uri.parse(_currentUrl));

    // 2) 초기 딥링크 처리
    final initial = await getInitialLink();
    if (initial != null) _handleDeepLink(initial);

    // 3) 실행 중 링크 스트림
    _sub = linkStream.listen((String? link) {
      if (link != null) _handleDeepLink(link);
    }, onError: (e) {});
  }

  void _handleDeepLink(String link) async {
    Uri uri;
    try {
      uri = Uri.parse(link);
    } catch (_) { return; }

    // crazyview://open?url=..., crazyview://open, crazyview://settings
    final host = uri.host; // 'open' or 'settings' (Android에서 host 없을 수 있음)
    final path = uri.path; // 일부 기기에서 host 대신 path에 올 때가 있어 보정용

    // 호스트/패스 중에 'settings'가 있으면 설정 화면
    if (host == 'settings' || path.contains('settings')) {
      if (!mounted) return;
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (_) => SettingsPage(initialUrl: _currentUrl, onSave: (url) async {
      //     await _applyUrl(url);
      //     Navigator.pop(context);
      //   }),
      // ));

      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => SettingsPage(initialUrl: _currentUrl)),
      );
      if (result != null) {
        await _applyUrl(result);
      }

      return;
    }

    // 기본은 open
    final newUrl = uri.queryParameters['url'];
    if (newUrl != null && newUrl.isNotEmpty) {
      await _applyUrl(newUrl);
    } else {
      // 마지막 위치로 (이미 열려 있으면 포그라운드 전환만)
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(kPrefsKeyMainUrl) ?? kDefaultUrl;
      await _applyUrl(last);
    }
  }

  Future<void> _applyUrl(String newUrl) async {
    _currentUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsKeyMainUrl, _currentUrl);

    // 필요하면 쿠키/캐시 초기화 (선택)
    // final cookieMgr = WebViewCookieManager();
    // await cookieMgr.clearCookies();

    await _wv.loadRequest(Uri.parse(_currentUrl));
    setState(() => _status = 'Loaded');
  }

  Future<void> _goHome() async {
    final prefs = await SharedPreferences.getInstance();
    final home = prefs.getString(kPrefsKeyMainUrl) ?? kDefaultUrl;
    await _wv.loadRequest(Uri.parse(home));
    setState(() => _status = 'Home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text(_status),
        title: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home),
          onPressed: _goHome
        ),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(initialUrl: _currentUrl),
                ),
              );
              if (result != null) {
                await _applyUrl(result);
              }
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: _wv),
    );
  }
}

/// 설정 화면: URL 입력 → 저장
class SettingsPage extends StatefulWidget {
  final String initialUrl;
  const SettingsPage({super.key, required this.initialUrl});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  bool _isValidHttpUrl(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  void _save() {
    final text = _controller.text.trim();
    if (!_isValidHttpUrl(text)) {
      setState(() => _error = 'http 또는 https URL을 입력하세요.');
      return;
    }
    Navigator.pop(context, text);
  }

  void _resetToDefault() {
    _controller.text = kDefaultUrl;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: '메인 URL',
                hintText: 'https://example.com',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('저장'),
                  onPressed: _save,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('기본값으로'),
                  onPressed: _resetToDefault,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '저장 후 앱 재시작은 필요 없습니다. 즉시 해당 URL로 새로 고침합니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// 작은 확장: 플랫폼별 setBackgroundColor 안전 호출
extension _BgExt on WebViewController {
  void setBackgroundColorIfSupported() {
    if (Platform.isIOS || Platform.isAndroid) {
      setBackgroundColor(Colors.white);
    }
  }
}