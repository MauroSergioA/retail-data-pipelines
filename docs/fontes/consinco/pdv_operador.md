# Pipeline: pdv_operador

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.PDV_OPERADOR` (Oracle) |
| Destino | `raw.pdv_operador` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/pdv_operador.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de operadores de PDV por loja. Referenciado em `maxv_abcdistribbase`
pela coluna `seqoperador`. Vinculado a `ge_pessoa` via `seqpessoa`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja (FK → max_empresa) |
| `SEQOPERADOR` | `seqoperador` | INTEGER | Código sequencial do operador na loja |
| `CODOPERADOR` | `codoperador` | TEXT | Código do operador usado no PDV |
| `FUNCAOOPERADOR` | `funcaooperador` | TEXT | Função do operador |
| `STATUSOPERADOR` | `statusoperador` | TEXT | Status do operador |
| `SEQPESSOA` | `seqpessoa` | INTEGER | Código da pessoa (FK → ge_pessoa) |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
