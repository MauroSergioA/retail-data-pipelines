# Pipeline: etlv_categoria

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.ETLV_CATEGORIA` (Oracle) |
| Destino | `raw.etlv_categoria` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/etlv_categoria.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

View Oracle que entrega a hierarquia de categorias de produtos já pivotada em até
3 níveis (categoria → subcategoria → grupo) por família e divisão comercial.

Diferente da `map_categoria` (estrutura flat por nível individual, com metas de
margem/markup), a `etlv_categoria` é a fonte correta para navegar a hierarquia
de categorias e classificar produtos no Power BI.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NRODIVISAO` | `nrodivisao` | INTEGER | Número da divisão comercial |
| `SEQFAMILIA` | `seqfamilia` | INTEGER | Código da família (FK para map_familia) |
| `SKCATEGORIA` | `skcategoria` | INTEGER | Chave surrogate da categoria completa |
| `CATEGORIACOMPLETA` | `categoriacompleta` | TEXT | Hierarquia completa concatenada |
| `SEQCATEGORIAN1` | `seqcategorian1` | INTEGER | Código da categoria nível 1 |
| `CATEGORIAN1` | `categorian1` | TEXT | Descrição da categoria nível 1 |
| `SEQCATEGORIAN2` | `seqcategorian2` | INTEGER | Código da categoria nível 2 |
| `CATEGORIAN2` | `categorian2` | TEXT | Descrição da categoria nível 2 |
| `SEQCATEGORIAN3` | `seqcategorian3` | INTEGER | Código da categoria nível 3 |
| `CATEGORIAN3` | `categorian3` | TEXT | Descrição da categoria nível 3 |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Granularidade e deduplicação

A granularidade da fonte é `(nrodivisao, seqfamilia)` — uma família pode aparecer
em múltiplas divisões. O modelo `stg_etlv_categoria` resolve isso com ROW_NUMBER(),
priorizando a divisão 1 e usando fallback para a menor divisão disponível, garantindo
exatamente uma linha por família sem perda de dados.

## Modelo dbt downstream

```
raw.etlv_categoria
    └── staging.stg_etlv_categoria   (view — dedup ROW_NUMBER, cast, UPPER, _id_nome)
            └── dw.dim_produto_info
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-06-01 | Pipeline criado e primeira carga executada |
