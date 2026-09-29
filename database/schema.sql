-- Esquema inicial do Aplicativo de Gastos.
-- Requer MySQL 8.0.16 ou superior (restricoes CHECK aplicadas pelo servidor).
-- Conecte-se ao banco de dados da aplicacao antes de executar este arquivo.

CREATE TABLE IF NOT EXISTS usuarios (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(254) NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_usuarios_email (email)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS categorias_gastos (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    usuario_id BIGINT UNSIGNED NOT NULL,
    nome VARCHAR(80) NOT NULL,
    ativa BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categorias_usuario_nome (usuario_id, nome),
    UNIQUE KEY uq_categorias_usuario_id (usuario_id, id),
    CONSTRAINT fk_categorias_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vendas (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    usuario_id BIGINT UNSIGNED NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    valor DECIMAL(13, 2) NOT NULL,
    data_venda DATE NOT NULL,
    hora_venda TIME NOT NULL,
    forma_pagamento ENUM(
        'dinheiro',
        'pix',
        'cartao_debito',
        'cartao_credito',
        'outro'
    ) NOT NULL,
    observacao TEXT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_vendas_usuario_data (usuario_id, data_venda, hora_venda, id),
    KEY idx_vendas_usuario_pagamento (usuario_id, forma_pagamento, data_venda),
    CONSTRAINT chk_vendas_valor_positivo CHECK (valor > 0),
    CONSTRAINT fk_vendas_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS gastos (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    usuario_id BIGINT UNSIGNED NOT NULL,
    categoria_id BIGINT UNSIGNED NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    valor DECIMAL(13, 2) NOT NULL,
    data_gasto DATE NOT NULL,
    hora_gasto TIME NOT NULL,
    observacao TEXT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_gastos_usuario_data (usuario_id, data_gasto, hora_gasto, id),
    KEY idx_gastos_usuario_categoria_data (usuario_id, categoria_id, data_gasto),
    CONSTRAINT chk_gastos_valor_positivo CHECK (valor > 0),
    CONSTRAINT fk_gastos_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gastos_categoria_usuario
        FOREIGN KEY (usuario_id, categoria_id)
        REFERENCES categorias_gastos (usuario_id, id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
