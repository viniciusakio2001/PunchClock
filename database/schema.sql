-- Sistema de ponto: criação das tabelas (PostgreSQL)
-- Modelo: um banco por cliente. Cada banco pertence a uma única empresa.

CREATE TABLE empresas (
    id          SERIAL PRIMARY KEY,
    razaosocial TEXT NOT NULL,
    cnpj        TEXT NOT NULL UNIQUE,
    fusohorario TEXT NOT NULL,   -- nome IANA, ex.: 'America/Sao_Paulo'
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cargo (
    id        SERIAL PRIMARY KEY,
    descricao TEXT NOT NULL
);

-- Usuários: autenticação por login e senha com hash
CREATE TABLE usuarios (
    id            SERIAL PRIMARY KEY,
    nome          TEXT NOT NULL,
    login         VARCHAR(32) NOT NULL UNIQUE,
    senha_hash    TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    perfil        TEXT NOT NULL CHECK (perfil IN ('funcionario', 'gestor', 'rh', 'admin')),
    cpf           TEXT NOT NULL,
    cargo_id      INTEGER NOT NULL REFERENCES cargo(id),
    carga_horaria INTEGER,
    regime        TEXT NOT NULL CHECK (regime IN ('clt', 'pj', 'autonomo', 'menor_aprendiz', 'estagio'))
);

-- Jornada programada: uma linha por dia da semana (0 a 6). NULL em todas as colunas = folga.
CREATE TABLE usuario_jornadatrabalho (
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    dia_da_semana   INTEGER NOT NULL CHECK (dia_da_semana BETWEEN 0 AND 6),
    entrada         TIME,
    saida_almoco    TIME,
    entrada_almoco  TIME,
    saida           TIME,
    PRIMARY KEY (usuario_id, dia_da_semana),
    CHECK (
        (entrada IS NULL AND saida_almoco IS NULL AND entrada_almoco IS NULL AND saida IS NULL)
        OR (entrada IS NOT NULL AND saida_almoco IS NOT NULL
            AND entrada_almoco IS NOT NULL AND saida IS NOT NULL
            AND entrada < saida_almoco AND saida_almoco < entrada_almoco AND entrada_almoco < saida)
    )
);

-- Configurações da empresa: uma linha por chave
CREATE TABLE configuracoes (
    id              SERIAL PRIMARY KEY,
    chave           TEXT NOT NULL UNIQUE,
    valor           TEXT NOT NULL,
    tipo_dado       TEXT NOT NULL CHECK (tipo_dado IN ('inteiro', 'booleano', 'dia_do_mes', 'mes_referencia', 'comportamento')),
    atualizado_em   TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_por  INTEGER REFERENCES usuarios(id)
);

CREATE TABLE historico_configuracoes (
    id               SERIAL PRIMARY KEY,
    configuracao_id  INTEGER NOT NULL REFERENCES configuracoes(id),
    valor_anterior   TEXT,
    valor_novo       TEXT NOT NULL,
    alterado_por     INTEGER NOT NULL REFERENCES usuarios(id),
    alterado_em      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Batidas. Nunca são editadas nem apagadas.
CREATE TABLE registros_ponto (
    id              SERIAL PRIMARY KEY,
    funcionario_id  INTEGER NOT NULL REFERENCES usuarios(id),
    data_hora       TIMESTAMPTZ NOT NULL,
    tipo            TEXT NOT NULL CHECK (tipo IN ('entrada', 'entrada_almoco', 'saida_almoco', 'saida')),
    origem          TEXT NOT NULL CHECK (origem IN ('batida', 'inclusao', 'ajuste', 'anulacao')),
    referencia_id   INTEGER REFERENCES registros_ponto(id),
    CHECK ((origem IN ('batida', 'inclusao')) = (referencia_id IS NULL))
);

CREATE TABLE solicitacoes_ajuste (
    id                    SERIAL PRIMARY KEY,
    funcionario_id        INTEGER NOT NULL REFERENCES usuarios(id),
    tipo                  TEXT NOT NULL CHECK (tipo IN ('ajuste', 'inclusao', 'exclusao')),
    registro_original_id  INTEGER REFERENCES registros_ponto(id),
    data_hora_alvo        TIMESTAMPTZ NOT NULL,
    tipo_alvo             TEXT NOT NULL CHECK (tipo_alvo IN ('entrada', 'entrada_almoco', 'saida_almoco', 'saida')),
    horario_solicitado    TIMESTAMPTZ,
    justificativa         TEXT NOT NULL,
    status                TEXT NOT NULL DEFAULT 'pendente'
                          CHECK (status IN ('pendente', 'aprovada', 'rejeitada', 'expirada')),
    criado_em             TIMESTAMPTZ NOT NULL DEFAULT now(),
    decidida_em           TIMESTAMPTZ,
    CHECK (
        (tipo = 'inclusao' AND registro_original_id IS NULL AND horario_solicitado IS NOT NULL)
        OR (tipo = 'ajuste' AND registro_original_id IS NOT NULL AND horario_solicitado IS NOT NULL)
        OR (tipo = 'exclusao' AND registro_original_id IS NOT NULL AND horario_solicitado IS NULL)
    )
);

-- Uma única pendência por funcionário, horário e tipo
CREATE UNIQUE INDEX uma_pendencia_por_horario_tipo
    ON solicitacoes_ajuste (funcionario_id, data_hora_alvo, tipo_alvo)
    WHERE status = 'pendente';

CREATE TABLE decisoes_ajuste (
    id              SERIAL PRIMARY KEY,
    solicitacao_id  INTEGER NOT NULL REFERENCES solicitacoes_ajuste(id),
    aprovador_id    INTEGER NOT NULL REFERENCES usuarios(id),
    papel           TEXT NOT NULL CHECK (papel IN ('gestor', 'rh')),
    decisao         TEXT NOT NULL CHECK (decisao IN ('aprovada', 'rejeitada')),
    decidido_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (solicitacao_id, papel)
);

-- Ligação entre a batida e a solicitação que a gerou (dependência circular, por isso fica no final)
ALTER TABLE registros_ponto
    ADD COLUMN solicitacao_id INTEGER REFERENCES solicitacoes_ajuste(id);