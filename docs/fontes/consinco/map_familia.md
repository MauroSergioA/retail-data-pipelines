# Pipeline: map_familia

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAP_FAMILIA` (Oracle) |
| Destino | `raw.map_familia` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/map_familia.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de famílias de produtos. Agrupa produtos por características comuns —
se são pesáveis, quantas casas decimais aceitam na quantidade. Vincula a família
à sua marca.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQFAMILIA` | `seqfamilia` | INTEGER | Código sequencial — chave primária |
| `FAMILIA` | `familia` | TEXT | Descrição da família |
| `SEQMARCA` | `seqmarca` | INTEGER | Código da marca (FK → map_marca) |
| `PESAVEL` | `pesavel` | TEXT | Indica se os produtos são pesáveis: S/N |
| `PMTDECIMAL` | `pmtdecimal` | TEXT | Indica se aceita casas decimais na quantidade: S/N |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.map_familia
    └── staging.stg_map_familia   (view — cast, rename, UPPER, S/N → SIM/NÃO no dw)
            └── dw.dim_produto_info
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-27 | Pipeline criado |
