# Aplicativo Flutter

Aplicativo Android em português brasileiro para registrar vendas e gastos, consultar o histórico e visualizar relatórios. O aplicativo consome a API Flask configurada pela variável `API_BASE_URL`.

Consulte o [README principal](../README.md) para saber como instalar, executar a API localmente e compilar o APK.

## Requisitos de desenvolvimento

- Flutter estável;
- JDK 17;
- Android SDK;
- dispositivo Android ou emulador.

## Instalar dependências e validar o projeto

```bash
flutter pub get
flutter analyze
flutter test
```

## Executar durante o desenvolvimento

Informe a URL da API terminando em `/api`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

`10.0.2.2` é o endereço usado por um emulador Android para acessar a API executada no computador. Em um celular físico, substitua pelo IP do computador na rede local.

## Gerar APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://SEU-ENDERECO/api
```

O APK ficará em `build/app/outputs/flutter-apk/app-release.apk`.
