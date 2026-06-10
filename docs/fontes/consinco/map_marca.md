# Pipeline: map_marca

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAP_MARCA` (Oracle) |
| Destino | `raw.map_marca` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/map_marca.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de marcas de produtos. Vinculado à família via `map_familia.seqmarca`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQMARCA` | `seqmarca` | INTEGER | Código sequencial — chave primária |
| `MARCA` | `marca` | TEXT | Descrição da marca |
| `STATUS` | `status` | TEXT | Status da marca |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.map_marca
    └── staging.stg_map_marca   (view — cast, rename, UPPER)
            └── dw.dim_produto_info
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-27 | Pipeline criado |
