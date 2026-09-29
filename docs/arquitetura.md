# Arquitetura — Aplicativo de Gastos

## Objetivo da Etapa 1

Definir uma arquitetura simples, segura e compreensível para registrar vendas e despesas, consultar resultados por dia e mês e distribuir o aplicativo para Android.

## Decisões

- **Aplicativo:** Flutter e Dart, com foco em Android e interface em português do Brasil.
- **Backend:** Python com Flask, expondo uma API REST em JSON.
- **Banco de dados:** MySQL, com valores financeiros em `DECIMAL` e acesso por ORM/consultas parametrizadas.
- **Comunicação:** o aplicativo consome a API por HTTPS; os dados financeiros oficiais ficam no banco do backend, não apenas no celular. A API receberá valores monetários como texto decimal para evitar perda de precisão na conversão por ponto flutuante.
- **GitHub:** repositório para código e documentação; GitHub Actions poderá automatizar testes e builds, e uma GitHub Release poderá distribuir o APK.
- **Hospedagem:** API Flask e MySQL precisam de um provedor externo. O GitHub não executa esse backend nem fornece um serviço MySQL para produção. O provedor será escolhido na etapa de deploy, após conferir documentação, limites, preços e requisitos atuais.

## Visão da arquitetura

```text
Aplicativo Flutter (Android)
          │ HTTPS / JSON
          ▼
       API REST
          │
          ▼
     Backend Flask
          │ ORM / SQL parametrizado
          ▼
        MySQL
```

O aplicativo exibirá erros de conexão de forma amigável. Na primeira versão, operações que exigem gravação dependerão de conexão com a API; não haverá sincronização offline implícita ou cópias locais tratadas como fonte oficial dos dados.

## Organização proposta

```text
aplicativo-de-gastos/
├── app/                    # Aplicativo Flutter
├── backend/                # API Flask, modelos, serviços e configurações
├── database/               # Scripts versionados de criação/evolução do banco
├── docs/                   # Arquitetura e documentação complementar
├── .env.example            # Nomes e exemplos seguros de configuração
├── .gitignore              # Exclusão de segredos e artefatos locais
└── README.md               # Instalação, uso, API e distribuição
```

Esta é uma estrutura-alvo; os diretórios de implementação serão criados nas etapas correspondentes, evitando adicionar código antes de validar o planejamento.

## Regras importantes de domínio

- Vendas e despesas serão registros distintos, com identificador, descrição, valor, data/hora, observação opcional e data de criação.
- Vendas também terão forma de pagamento; despesas terão categoria.
- Cada registro pertencerá ao usuário autenticado por uma chave estrangeira, e as consultas serão limitadas aos dados desse usuário.
- Valor monetário será decimal no banco e validado como positivo na API. O aplicativo enviará valores como texto decimal, sem depender de arredondamento binário para cálculos financeiros.
- Faturamento bruto é a soma das vendas do período; gastos totais são a soma das despesas; resultado líquido é faturamento bruto menos gastos totais.
- Na primeira versão, “ganhos” no resumo será representado pelas vendas/faturamento; não haverá um terceiro tipo de lançamento independente sem confirmação.
- Relatórios usarão limites de data inclusivos/exclusivos consistentes e o fuso horário definido para o negócio, para evitar registros no dia ou mês incorretos.
- Atualizações e exclusões persistirão no backend; consultas e totais serão recalculados a partir dos registros salvos.

## Segurança e configuração

- Segredos e credenciais ficam em variáveis de ambiente; `.env` não será versionado.
- A API usará tokens Bearer JWT para proteger os dados financeiros; senhas serão armazenadas somente com hash seguro e os endpoints privados verificarão a identidade do usuário.
- A API validará entradas e retornará códigos HTTP e mensagens JSON apropriados.
- A conexão pública entre aplicativo e API usará HTTPS; credenciais do banco não serão incluídas no aplicativo.

## Plano de execução por etapas

1. Planejamento e arquitetura — este documento.
2. Banco de dados — esquema e configuração MySQL.
3. Backend Flask — estrutura e configuração.
4. API REST — endpoints, validação e tratamento de erros.
5. Cadastro de vendas.
6. Cadastro de despesas.
7. Cálculos financeiros.
8. Relatório diário.
9. Relatório mensal.
10. Dashboard.
11. Aplicativo mobile.
12. Integração do aplicativo com a API.
13. Testes.
14. Deploy — escolher e configurar hospedagem após verificar as condições atuais.
15. Build e validação do APK.
16. GitHub Release com o APK.
17. README final, instruções de instalação e documentação da API.

Cada etapa será validada antes de avançar para a próxima.

## Limites desta etapa

Esta etapa define a arquitetura e o plano. Ainda não instala dependências, não implementa endpoints ou telas, não provisiona serviços externos e não publica arquivos no GitHub. A publicação exigirá um repositório remoto e acesso autorizado à conta/organização correspondente.

## Execução e validação

Revise este documento para confirmar as decisões de arquitetura antes de iniciar a Etapa 2. Nenhum comando de execução ou teste de aplicativo se aplica a esta etapa documental.

**Mensagem de commit sugerida:** `docs: definir arquitetura do aplicativo de gastos`
