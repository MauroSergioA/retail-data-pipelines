# Pipeline: maxv_abcdistribbase (fato_venda)

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAXV_ABCDISTRIBBASE` + joins (Oracle) |
| Destino | `raw.maxv_abcdistribbase` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/maxv_abcdistribbase.hpl` |
| Frequência hot | 4× por dia — janela: `DTAVDA = hoje` |
| Frequência cold | 1× por madrugada — janela: `DTAVDA >= hoje - 5` |
| Estratégia raw | TRUNCATE + INSERT (buffer rolling) |
| Volume aprox. | ~67.000 linhas/dia (agregado por hora × produto × documento) |

## Por que este pipeline é diferente

A query não extrai uma tabela simples. Ela executa um SELECT complexo no Oracle que:

1. **Une 9 tabelas** (`MAXV_ABCDISTRIBBASE`, `MRL_CUSTODIA`, `MAP_PRODUTO` × 2,
   `MAP_FAMDIVISAO`, `MAP_FAMEMBALAGEM`, `MAX_EMPRESA`, `MAX_DIVISAO`,
   `MAP_PRODACRESCCUSTORELAC`)
2. **Chama funções Oracle** para calcular lucro e custo — lógica fiscal que não pode
   ser reproduzida fora do Oracle
3. **Agrega via GROUP BY** — cada linha representa um item × hora × documento

As funções Oracle chamadas:

| Função | Resultado | Observação |
|--------|-----------|-----------|
| `FC5_AbcDistribLucratividade` | `vlrlucro` | ~50 parâmetros, lógica fiscal completa |
| `FC5_ABCDISTRIBCUSTOBRUTO` | `ctobrutovda` | ~30 parâmetros, custo bruto |
| `fc5_divide` | divisão segura | Utilitário interno |
| `fmrl_seqpromocProd` | `vlrvendapromoc` | Valor promocional |
| `F_RETACRESCCUSTORELACABC` | % acréscimo | Produtos com custo relacionado |

O custo líquido (`vlrctoliqvda`) é calculado como expressão SQL pura (sem função Oracle).

## Parâmetro WINDOW_DAYS

O pipeline recebe o parâmetro `WINDOW_DAYS` que controla a janela de extração:

```sql
AND V.DTAVDA >= TRUNC(SYSDATE) - ${WINDOW_DAYS}
```

| Workflow | WINDOW_DAYS | Janela |
|----------|-------------|--------|
| `run_hot.hwf` | `0` | Somente hoje |
| `run_cold.hwf` | `5` | Últimos 5 dias |

## Colunas carregadas no raw

| Coluna raw | Tipo Oracle | Descrição |
|-----------|------------|-----------|
| `datahora` | TIMESTAMP | `TRUNC(DTAHORLANCTO, 'HH')` — hora truncada |
| `nrodocto` | BIGINT | Número do documento (cupom) |
| `seriedocto` | TEXT | Série do documento |
| `nroformapagto` | INTEGER | Código da forma de pagamento |
| `nroempresa` | INTEGER | Código da loja |
| `nrosegmento` | INTEGER | Segmento da venda |
| `codgeraloper` | INTEGER | Código de operação (filtrado: 800, 810, 820, 828, 202) |
| `seqproduto` | INTEGER | Código do produto |
| `seqoperador` | INTEGER | Código do operador de caixa |
| `checkout` | INTEGER | Número do checkout |
| `qtditem` | NUMERIC | Quantidade vendida |
| `qtddevolitem` | NUMERIC | Quantidade devolvida |
| `vlritem` | NUMERIC | Valor bruto do item |
| `vlrdevolitem` | NUMERIC | Valor de devolução |
| `vlrdescitem` | NUMERIC | Desconto líquido (desconto - desconto devolução) |
| `vlrvendapromoc` | NUMERIC | Valor de venda promocional |
| `vlrlucro` | NUMERIC | Lucro calculado via FC5_AbcDistribLucratividade |
| `ctobrutovda` | NUMERIC | Custo bruto via FC5_ABCDISTRIBCUSTOBRUTO |
| `vlrctoliqvda` | NUMERIC | Custo líquido (expressão SQL) |
| `_loaded_at` | TIMESTAMP | Timestamp de início da extração |

## Modelo dbt downstream

```
raw.maxv_abcdistribbase
    └── staging.stg_maxv_abcdistribbase   (view — cast, rename, derivações)
            └── dw.fato_venda              (incremental — delete+insert, chave composta)
```

## Observações operacionais

- O raw é um **buffer temporário** — cada run trunca e recarrega apenas a janela
- O dw **acumula histórico** — o incremental nunca apaga dados fora da janela atual
- Múltiplos runs por dia são seguros: o upsert por chave composta previne duplicatas
- A query demora ~90 segundos para D-1 (~134k linhas). D-5 deve levar ~7 minutos.

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-28 | Pipeline criado com parâmetro WINDOW_DAYS, validado com D-1 (134.245 linhas, valores conferidos com Power BI) |
