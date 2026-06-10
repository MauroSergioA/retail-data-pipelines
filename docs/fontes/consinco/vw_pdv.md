# Pipeline: vw_pdv

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCOMONITOR.VW_PDV` (Oracle — schema monitor) |
| Destino | `raw.vw_pdv` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/vw_pdv.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Checkouts (caixas PDV) por loja. A extração usa INNER JOIN com `max_empresa`
na coluna `nrosegmentoprinc` para garantir que apenas o segmento principal de
cada loja seja incluído — evitando duplicação de caixas que aparecem em
múltiplos segmentos.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja (FK → max_empresa) |
| `NROCHECKOUT` | `nrocheckout` | INTEGER | Número do checkout (caixa) |
| `NROSEGMENTO` | `nrosegmento` | INTEGER | Segmento principal da loja |
| `ATIVO` | `ativo` | TEXT | Checkout ativo: S/N |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.vw_pdv
    └── staging.stg_vw_pdv   (view — cast, rename; ATIVO S/N → status_pdv ATIVO/INATIVO)
            └── dw.dim_empresa_info  (agrega total_pdv_ativo por loja)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
| 2026-05-29 | Coluna ATIVO adicionada na extração Oracle |
