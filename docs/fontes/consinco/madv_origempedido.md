# Pipeline: madv_origempedido

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MADV_ORIGEMPEDIDO` (Oracle) |
| Destino | `raw.madv_origempedido` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/madv_origempedido.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Domínio de origens de pedido de compras.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `ORIGEMPEDIDO` | `origempedido` | TEXT | Código da origem — chave primária |
| `DESCORIGEMPEDIDO` | `descorigempedido` | TEXT | Descrição da origem |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
