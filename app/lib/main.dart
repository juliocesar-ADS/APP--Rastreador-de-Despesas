import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/local_store.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const ControleGastosApp());
}

class ControleGastosApp extends StatefulWidget {
  const ControleGastosApp({super.key, this.store});

  final LocalStore? store;

  @override
  State<ControleGastosApp> createState() => _ControleGastosAppState();
}

class _ControleGastosAppState extends State<ControleGastosApp> {
  late final LocalStore _store = widget.store ?? LocalStore();
  late Future<void> _initialization = _store.initialize();

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xff087f68);
    return MaterialApp(
      title: 'Rastreador de Despesas',
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
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LocalDatabaseError(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() => _initialization = _store.initialize());
              },
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return MainShell(store: _store);
        },
      ),
    );
  }
}

class _LocalDatabaseError extends StatelessWidget {
  const _LocalDatabaseError({required this.message, required this.onRetry});

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
              const Icon(Icons.storage_rounded, size: 40),
              const SizedBox(height: 16),
              const Text('Não foi possível abrir o banco local.'),
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
