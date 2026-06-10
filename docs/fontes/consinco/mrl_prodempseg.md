# Pipeline: mrl_prodempseg

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MRL_PRODEMPSEG` (Oracle) |
| Destino | `raw.mrl_prodempseg` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mrl_prodempseg.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Parâmetros de produto por empresa e segmento. Contém preços, margens e
configurações de venda de cada produto em cada loja/segmento.

## Regra crítica de uso

**Nunca filtrar `nrosegmento IN (1)`** ao consultar esta tabela. Isso exclui
lojas cujo segmento principal é diferente de 1. O filtro correto é via
INNER JOIN com `max_empresa` na coluna `nrosegmentoprinc`:

```sql
INNER JOIN raw.max_empresa e
        ON e.nroempresa       = p.nroempresa
       AND e.nrosegmentoprinc = p.nrosegmento
```

## Filtros na extração

| Filtro | Valor | Motivo |
|--------|-------|--------|
| Nenhum | — | Extração completa (~1,5M linhas). O filtro `qtdembalagem = 1` e o join por segmento principal são aplicados nos modelos dw consumidores. |

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPRODUTO` | `seqproduto` | INTEGER | Código do produto — parte da chave |
| `QTDEMBALAGEM` | `qtdembalagem` | NUMERIC | Quantidade da embalagem — parte da chave |
| `NROSEGMENTO` | `nrosegmento` | INTEGER | Número do segmento — parte da chave |
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja — parte da chave |
| `STATUSVENDA` | `statusvenda` | TEXT | Status de venda: A = ativo, I = inativo |
| `PRECOBASENORMAL` | `precobasenormal` | NUMERIC | Preço base normal |
| `MOTIVOPRECOBASE` | `motivoprecobase` | TEXT | Motivo da última alteração do preço base |
| `PRECOGERNORMAL` | `precogernormal` | NUMERIC | Preço gerado praticado normal |
| `PRECOGERPROMOC` | `precogerpromoc` | NUMERIC | Preço gerado em promoção |
| `MOTIVOPRECOGERADO` | `motivoprecogerado` | TEXT | Motivo da última alteração do preço gerado |
| `PRECOVALIDNORMAL` | `precovalidnormal` | NUMERIC | Preço válido atual normal |
| `PRECOVALIDPROMOC` | `precovalidpromoc` | NUMERIC | Preço válido em promoção |
| `MOTIVOPRECOVALIDO` | `motivoprecovalido` | TEXT | Motivo da última alteração do preço válido |
| `MARGEMLUCROPRODEMPSEG` | `margemlucroprodempseg` | NUMERIC | Percentual de margem de lucro |
| `VLRCUSTOLIQDIAPRECIF` | `vlrcustoliqdiaprecif` | NUMERIC | Custo líquido base para precificação do dia |
| `DTAGERACAOPRECO` | `dtageracaopreco` | DATE | Data de geração do preço |
| `DTAVALIDACAOPRECO` | `dtavalidacaopreco` | DATE | Data de validação do preço |
| `DTAALTERACAO` | `dtaalteracao` | DATE | Data da última alteração |
| `DATAHORAALTERACAO` | `datahoraalteracao` | TIMESTAMP | Timestamp da última alteração |
| `DTAHORALTSTATUSVDA` | `dtahoraltstatusvda` | TIMESTAMP | Timestamp da última alteração do status de venda |
| `PRECOEMITIDOPROMOC` | `precoemitidopromoc` | NUMERIC | Preço emitido para promoção |
| `PRECOGERNORMALPROG` | `precogernormalprog` | NUMERIC | Preço gerado agendado |
| `DTAGERACAOPRECOPROG` | `dtageracaoprecoprog` | DATE | Data de ativação do preço agendado |
| `SEQPROMOCAO` | `seqpromocao` | INTEGER | FK para promoção vinculada |
| `INDREVISAOPRECO` | `indrevisaopreco` | TEXT | Indica se está em revisão de preço |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```text
raw.mrl_prodempseg
    └── staging.stg_mrl_prodempseg
            └── dw.dim_produto_empresa  (join por segmento_principal + qtd_embalagem = 1)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-06-04 | Colunas documentadas; staging `stg_mrl_prodempseg` criado |
| 2026-05-29 | Pipeline criado e carregado |
