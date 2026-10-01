# Armazenamento local do aplicativo

O aplicativo Android funciona de forma independente da API e da pasta `backend/`. Ao iniciar pela primeira vez, cria um banco SQLite privado no armazenamento interno do aplicativo.

## Dados armazenados

O banco guarda:

- vendas, incluindo valor, data, hora e forma de pagamento;
- despesas, incluindo categoria, valor, data e hora;
- categorias de despesas.

Os cálculos do painel e dos relatórios são feitos usando os dados desse banco. Os valores monetários são armazenados como centavos inteiros, evitando erros de arredondamento.

## Privacidade e cópias de segurança

- O aplicativo não precisa de permissão de internet.
- Não há conta, servidor remoto ou sincronização.
- O Android está configurado para não incluir o banco nas cópias automáticas do sistema.
- Desinstalar o aplicativo pode apagar o banco e todos os lançamentos.
- Para trocar de aparelho ou guardar uma cópia, mantenha as informações importantes registradas separadamente.

## Instalar

Baixe o APK mais recente pela área [Releases](https://github.com/juliocesar-ADS/APP--Rastreador-de-Despesas/releases/latest) e instale no Android. Não é necessário instalar Termux ou configurar um serviço local.

## Compilar para desenvolvimento

Requisitos: Flutter estável, JDK 17 e Android SDK.

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

O APK fica em `app/build/app/outputs/flutter-apk/app-release.apk`.
