# dw.fato_venda

## Descrição

Fato de vendas PDV da rede de varejo. Histórico acumulado desde 01/08/2022.
Inclui vendas (`codgeraloper` 800, 810, 820, 828) e devoluções (202).

Métricas de custo e lucro calculadas pelas funções Oracle `FC5_AbcDistribLucratividade` e
`FC5_ABCDISTRIBCUSTOBRUTO` no momento da extração pelo Hop — não replicáveis fora do Oracle.

## Linhagem

```
CONSINCO.MAXV_ABCDISTRIBBASE + 8 joins (Oracle)
    └── raw.maxv_abcdistribbase          (buffer rolling — TRUNCATE+INSERT)
            └── staging.stg_maxv_abcdistribbase   (view — cast, rename, derivações)
                    └── dw.fato_venda             (incremental — delete+insert)
```

## Materialização

| Atributo | Valor |
|----------|-------|
| Estratégia dbt | `incremental` / `delete+insert` |
| Granularidade | Hora × produto × documento × operador |
| Volume aprox. | ~67.000 linhas/dia |
| Histórico desde | 01/08/2022 |

## Chave única composta (10 colunas)

```sql
(dta_hora_venda, nro_empresa, nro_docto, serie_docto,
 checkout, nro_forma_pagto, nro_segmento, cod_geral_oper,
 seq_produto, seq_operador)
```

Cada combinação identifica unicamente um item × hora × documento.
`delete+insert` exclui o lote da janela atual antes de reinserir, evitando duplicatas em reprocessamentos.

## Janela incremental (dinâmica)

O dbt detecta automaticamente a janela carregada pelo Hop:

```sql
WHERE dta_venda >= (SELECT MIN(datahora::DATE) FROM raw.maxv_abcdistribbase)
```

- Hot (4×/dia, `WINDOW_DAYS=0`): reprocessa somente hoje
- Cold (1×/madrugada, `WINDOW_DAYS=5`): reprocessa D-5

## Colunas

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `dta_hora_venda` | TIMESTAMP | Hora truncada do lançamento (`TRUNC(DTAHORLANCTO, 'HH')`) |
| `dta_venda` | DATE | Data da venda (derivada de `dta_hora_venda`) |
| `hora_venda` | INTEGER | Hora do dia 0–22 (derivada de `dta_hora_venda`) |
| `nro_empresa` | INTEGER | Código da loja |
| `nro_docto` | BIGINT | Número do documento (cupom fiscal) |
| `serie_docto` | TEXT | Série do documento |
| `checkout` | INTEGER | Número do caixa |
| `nro_documento` | TEXT | Chave do documento: `NN-NNNNNNNNN-SSSS-CC` |
| `nro_forma_pagto` | INTEGER | Código da forma de pagamento |
| `nro_segmento` | INTEGER | Código do segmento da venda |
| `cod_geral_oper` | INTEGER | Código da operação (800/810/820/828 = venda, 202 = devolução) |
| `seq_produto` | INTEGER | Código sequencial do produto |
| `seq_operador` | INTEGER | Código do operador de caixa |
| `qtd_venda_item` | NUMERIC | Quantidade vendida (bruta) |
| `qtd_devol_item` | NUMERIC | Quantidade devolvida |
| `qtd_venda_liq` | NUMERIC | Quantidade líquida (`qtd_venda_item - qtd_devol_item`) |
| `vlr_venda_item` | NUMERIC | Valor bruto de venda |
| `vlr_devol_item` | NUMERIC | Valor de devolução |
| `vlr_venda_liq` | NUMERIC | Valor líquido de venda (`vlr_venda_item - vlr_devol_item`) |
| `vlr_desconto_item` | NUMERIC | Desconto líquido aplicado |
| `vlr_venda_promoc` | NUMERIC | Valor de venda promocional |
| `vlr_lucro` | NUMERIC | Lucro calculado via `FC5_AbcDistribLucratividade` (Oracle) |
| `vlr_custo_bruto` | NUMERIC | Custo bruto via `FC5_ABCDISTRIBCUSTOBRUTO` (Oracle) |
| `vlr_custo_liquido` | NUMERIC | Custo líquido (expressão SQL pura) |
| `loaded_at` | TIMESTAMP | Timestamp da carga do pipeline Hop que originou o dado |

### nro_documento

Chave legível do documento fiscal, construída na staging:

```sql
LPAD(nroempresa, 2, '0') || '-' || LPAD(nrodocto, 9, '0')
    || '-' || seriedocto || '-' || LPAD(checkout, 2, '0')
```

Exemplo: `05-000123456-EE-01`

## Testes dbt

| Coluna | Testes |
|--------|--------|
| `dta_hora_venda` | `not_null` |
| `dta_venda` | `not_null` |
| `nro_empresa` | `not_null` |
| `nro_documento` | `not_null` |
| `seq_produto` | `not_null` |
| `cod_geral_oper` | `not_null`, `accepted_values: [800, 810, 820, 828, 202]` |
| `loaded_at` | `not_null` |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-28 | Modelo criado; 134.245 linhas (D-1) validadas contra Power BI |
| 2026-05-28 | Carga histórica iniciada (lote 1: 2022-08-01 → 2022-10-31) |
