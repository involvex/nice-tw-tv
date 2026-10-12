import 'dart:async';

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
  var _finished = false;
  Timer? _fragmentPoll;

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
    // The implicit-grant token lands in the URL *fragment*
    // (#access_token=...). Fragment-only changes don't trigger
    // onNavigationRequest, and some WebView versions strip the fragment
    // from onUrlChange — so poll window.location.href directly.
    _fragmentPoll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollLocationForToken(auth);
    });
  }

  Future<void> _pollLocationForToken(AuthRepository auth) async {
    if (_finished || !mounted) return;
    try {
      final href = await _controller.runJavaScriptReturningResult(
        'window.location.href',
      );
      final url = href is String ? href : href.toString();
      if (auth.isOAuthRedirect(url)) {
        final token = auth.extractTokenFromRedirect(url);
        if (token != null) _finish(token);
      }
    } on Object {
      // WebView not ready yet — the next tick retries.
    }
  }

  @override
  void dispose() {
    _fragmentPoll?.cancel();
    super.dispose();
  }

  Future<void> _finish(String token) async {
    // onNavigationRequest + onUrlChange can both fire for the same
    // redirect — only finish once.
    if (_finished) return;
    _finished = true;
    _fragmentPoll?.cancel();
    _fragmentPoll = null;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).completeLogin(token);
    } on Object catch (e) {
      _finished = false;
      // Resume polling so a retry still captures the token.
      _fragmentPoll?.cancel();
      final auth = ref.read(authRepositoryProvider);
      _fragmentPoll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _pollLocationForToken(auth);
      });
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sign-in failed: $e';
        });
      }
      return;
    }
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
