# Banco de dados

O banco oficial da aplicação é MySQL. O esquema inicial está em [`schema.sql`](./schema.sql) e requer MySQL 8.0.16 ou superior para que as restrições `CHECK` de valores positivos sejam aplicadas pelo servidor.

## Estrutura

- `usuarios`: contas, e-mails únicos e hashes de senha; senhas em texto puro não devem ser armazenadas.
- `categorias_gastos`: categorias pertencentes a cada usuário. Categorias usadas em lançamentos não são apagadas; devem ser desativadas para preservar o histórico.
- `vendas`: descrição, valor decimal, data, horário, forma de pagamento e observação opcional.
- `gastos`: descrição, valor decimal, data, horário, observação opcional e categoria.

Vendas e gastos pertencem a um usuário. A chave estrangeira composta de `gastos` impede associar um gasto à categoria de outra conta. As chaves e índices permitem integridade referencial e consultas por usuário, data, forma de pagamento e categoria.

Os campos `data_venda`/`hora_venda` e `data_gasto`/`hora_gasto` representam a data e o horário informados para a movimentação. `criado_em` registra quando o banco recebeu o registro. A API definirá o fuso de negócio para datas padrão e relatórios.

Valores usam `DECIMAL(13, 2)`, apropriado para dinheiro, e restrições `CHECK` rejeitam valores iguais ou menores que zero. A API também deverá validar entradas e enviar valores decimais sem convertê-los para ponto flutuante.

## Criar e carregar o esquema

1. Crie um banco vazio com codificação `utf8mb4` usando o MySQL Workbench ou a linha de comando:

   ```sql
   CREATE DATABASE aplicativo_gastos
     CHARACTER SET utf8mb4
     COLLATE utf8mb4_unicode_ci;
   ```

2. Na raiz do repositório, carregue `database/schema.sql` no banco criado. No PowerShell, com o cliente MySQL instalado:

   ```powershell
   Get-Content .\database\schema.sql -Raw |
     mysql --default-character-set=utf8mb4 --user=SEU_USUARIO --password --database=aplicativo_gastos
   ```

   O cliente solicitará a senha sem colocá-la no comando. Também é possível abrir e executar o arquivo no MySQL Workbench com `aplicativo_gastos` selecionado.

3. Confira a criação:

   ```sql
   SHOW TABLES;
   DESCRIBE usuarios;
   DESCRIBE categorias_gastos;
   DESCRIBE vendas;
   DESCRIBE gastos;
   ```

O script cria as tabelas caso ainda não existam; ele não apaga tabelas nem dados. Alterações futuras do esquema deverão ser entregues como migrações versionadas, sem editar manualmente um banco já em uso.

## Categorias iniciais

Ao criar uma conta, a aplicação deverá inserir na mesma transação as categorias padrão: Compras, Funcionários, Transporte, Manutenção, Contas, Aluguel, Materiais e Outros. A tabela suporta categorias adicionais por usuário; categorias em uso devem ser desativadas, não excluídas.

## Operação e segurança

Crie um usuário MySQL próprio para a aplicação, concedendo acesso apenas ao banco `aplicativo_gastos`; não use a conta `root` no backend. A senha e os demais dados de conexão serão configurados por variáveis de ambiente na etapa do backend. Nunca versione credenciais.

O script não cria usuários, contas ou movimentações de demonstração. O backend será responsável por transações de cadastro/edição e por restringir cada consulta à conta autenticada.

## Validação desta etapa

Execute os comandos de verificação acima em uma instância MySQL local. Se o cliente ou servidor MySQL não estiver instalado, instale/configure o MySQL antes de validar o esquema. Ainda não há backend nesta etapa.

O esquema foi carregado e exercitado em uma instância MySQL 8.0.45 temporária e isolada. Foram verificadas a criação das quatro tabelas, a soma decimal de vendas e gastos (`0,10 + 0,20 = 0,30`), a rejeição de valor zero e a rejeição de um gasto associado à categoria de outro usuário. A instância e os dados temporários foram encerrados e removidos após o teste.
