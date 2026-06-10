# Pipeline: map_prodcodigo

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAP_PRODCODIGO` (Oracle) |
| Destino | `raw.map_prodcodigo` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/map_prodcodigo.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Códigos de acesso (EAN/barras) por produto e embalagem. Um produto pode ter
múltiplos códigos dependendo da embalagem (unitário, caixa, fardo, etc.).

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPRODUTO` | `seqproduto` | INTEGER | Código do produto (FK → map_produto) |
| `QTDEMBALAGEM` | `qtdembalagem` | NUMERIC | Quantidade da embalagem |
| `TIPCODIGO` | `tipcodigo` | TEXT | Tipo do código (EAN13, EAN8, interno, etc.) |
| `CODACESSO` | `codacesso` | TEXT | Código de barras/acesso |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
