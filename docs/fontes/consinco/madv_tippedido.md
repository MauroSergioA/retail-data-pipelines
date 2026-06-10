# Pipeline: madv_tippedido

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MADV_TIPPEDIDO` (Oracle) |
| Destino | `raw.madv_tippedido` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/madv_tippedido.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Domínio de tipos de pedido de compras. Extração via `SELECT *` —
colunas serão documentadas ao construir o modelo staging.

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
