# Aplicativo Flutter

App Android em português brasileiro para registrar vendas e gastos, ver o resultado financeiro e consultar o histórico e relatórios. As telas usam a API Flask; não há dados de demonstração nem operação offline.

Consulte o [README principal](../README.md) para preparar o banco, executar a API, configurar o ambiente Android e entender os passos de hospedagem.

## Desenvolvimento

Requisitos: Flutter estável, JDK 17 e Android SDK.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

O endereço `10.0.2.2` serve para o emulador Android acessar a máquina hospedeira. Para produção, compile com a URL HTTPS da API:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://seu-dominio/api
```
