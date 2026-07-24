import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authRepositoryProvider);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (auth.isOAuthRedirect(request.url)) {
              final token = auth.extractTokenFromRedirect(request.url);
              if (token != null) {
                _finish(token);
              } else {
                setState(() => _error = 'Could not read access token.');
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && auth.isOAuthRedirect(url)) {
              final token = auth.extractTokenFromRedirect(url);
              if (token != null) _finish(token);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(auth.buildAuthorizeUrl()));
  }

  Future<void> _finish(String token) async {
    await ref.read(authControllerProvider.notifier).completeLogin(token);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Twitch'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}
