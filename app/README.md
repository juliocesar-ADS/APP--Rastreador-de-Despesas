# Aplicativo Flutter

O aplicativo funciona offline e grava os dados no SQLite privado do Android. Não utiliza a API Flask, não requer login nem acesso à internet.

Para instalar no Android 7.0 ou superior, abra o [link direto do APK mais recente](https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas/releases/latest/download/app-release.apk), baixe o arquivo e toque em **Instalar**. O Android pode pedir autorização para instalar o arquivo baixado pelo navegador; essa confirmação é uma proteção do sistema.

## Desenvolvimento

Requisitos: Flutter estável, JDK 17 e Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

O APK gerado fica em `build/app/outputs/flutter-apk/app-release.apk`.

O banco é local ao aplicativo. Desinstalá-lo pode apagar todos os lançamentos; não há sincronização ou backup em nuvem.
