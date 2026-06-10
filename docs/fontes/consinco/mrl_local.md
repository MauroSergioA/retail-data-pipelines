# Pipeline: mrl_local

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MRL_LOCAL` (Oracle) |
| Destino | `raw.mrl_local` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mrl_local.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Locais de armazenagem de estoque por loja (salão, depósito, câmara fria, etc.).
Referenciado pelas colunas `locentrada` e `locsaida` em `mrl_produtoempresa`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja (FK → max_empresa) |
| `SEQLOCAL` | `seqlocal` | INTEGER | Código sequencial do local na loja |
| `LOCAL` | `local` | TEXT | Descrição do local |
| `TIPLOCAL` | `tiplocal` | TEXT | Tipo do local (loja, depósito, etc.) |
| `STATUS` | `status` | TEXT | Status do local |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
