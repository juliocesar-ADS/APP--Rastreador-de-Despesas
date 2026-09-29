import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const ControleGastosApp());
}

class ControleGastosApp extends StatefulWidget {
  const ControleGastosApp({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<ControleGastosApp> createState() => _ControleGastosAppState();
}

class _ControleGastosAppState extends State<ControleGastosApp> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late Future<String?> _session = _api.readToken();

  void _refreshSession() {
    setState(() {
      _session = _api.readToken();
    });
  }

  Future<void> _logout() async {
    await _api.logout();
    if (mounted) {
      setState(() {
        _session = Future.value(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xff087f68);
    return MaterialApp(
      title: 'Controle de Gastos',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff5f7f6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfff5f7f6),
          foregroundColor: Color(0xff17352f),
          centerTitle: false,
        ),
      ),
      home: FutureBuilder<String?>(
        future: _session,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SessionError(
              message: snapshot.error.toString(),
              onRetry: _refreshSession,
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null) {
            return AuthScreen(api: _api, onAuthenticated: _refreshSession);
          }
          return MainShell(api: _api, onLogout: _logout);
        },
      ),
    );
  }
}

class _SessionError extends StatelessWidget {
  const _SessionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 16),
              const Text('Não foi possível abrir sua sessão.'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
