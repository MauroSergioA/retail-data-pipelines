# Pipeline: madv_situacaoped

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MADV_SITUACAOPED` (Oracle) |
| Destino | `raw.madv_situacaoped` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/madv_situacaoped.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Domínio de situações de pedido de compras. Extração via `SELECT *` —
colunas serão documentadas ao construir o modelo staging.

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
