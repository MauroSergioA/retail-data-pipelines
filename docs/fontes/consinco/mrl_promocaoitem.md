# Pipeline: mrl_promocaoitem

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MRL_PROMOCAOITEM` (Oracle) |
| Destino | `raw.mrl_promocaoitem` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mrl_promocaoitem.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Itens de promoção — um registro por produto × promoção × empresa × segmento. Chave composta:
`seqproduto + qtdembalagem + seqpromocao + nroempresa + nrosegmento + centralloja`.

Contém o preço promocional por produto, percentual de desconto, datas de vigência por item
(podem sobrescrever as datas do cabeçalho `mrl_promocao`) e métricas de vendas realizadas
durante a promoção.

Volume total sem filtro: ~8M linhas. Com filtro `QTDEMBALAGEM = 1`: ~723k linhas.

## Filtros na extração

| Filtro | Valor | Motivo |
|--------|-------|--------|
| `QTDEMBALAGEM` | `= 1` | Embalagens maiores não são relevantes para analytics de preço unitário. Reduz de ~8M para ~723k linhas. |

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPRODUTO` | `seqproduto` | INTEGER | Código do produto — parte da chave |
| `QTDEMBALAGEM` | `qtdembalagem` | NUMERIC | Quantidade da embalagem — parte da chave (sempre 1 na extração) |
| `SEQPROMOCAO` | `seqpromocao` | INTEGER | Código da promoção — parte da chave |
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja — parte da chave |
| `NROSEGMENTO` | `nrosegmento` | INTEGER | Número do segmento — parte da chave |
| `CENTRALLOJA` | `centralloja` | TEXT | Origem — parte da chave |
| `PRECOPROMOCIONAL` | `precopromocional` | NUMERIC | Preço do produto nesta promoção |
| `PRECOSUGERIDO` | `precosugerido` | NUMERIC | Preço sugerido para a promoção |
| `STATUS` | `status` | TEXT | Status do item: A = ativo, I = inativo |
| `PERCDESCPROMOC` | `percdescpromoc` | NUMERIC | Percentual de desconto |
| `DTAINICIOPROM` | `dtainicioprom` | DATE | Início da vigência do item (sobrescreve cabeçalho quando preenchida) |
| `DTAFIMPROM` | `dtafimprom` | DATE | Fim da vigência do item (sobrescreve cabeçalho quando preenchida) |
| `QTDPREVISTAVDA` | `qtdprevistavda` | NUMERIC | Quantidade planejada de venda |
| `QTDTOTALVDA` | `qtdtotalvda` | NUMERIC | Quantidade efetivamente vendida durante a promoção |
| `VLRTOTALVDA` | `vlrtotalvda` | NUMERIC | Valor total efetivamente vendido durante a promoção |
| `QTDMEDIAVDAPROMOC` | `qtdmediavdapromoc` | NUMERIC | Média de venda durante a promoção |
| `NROACORDO` | `nroacordo` | INTEGER | Número do acordo comercial vinculado |
| `DTAINCLUSAO` | `dtainclusao` | DATE | Data de inclusão do item |
| `DTAGERACAO` | `dtageracao` | DATE | Data de geração do item |
| `DTAHORAALTERACAO` | `dtahoraalteracao` | TIMESTAMP | Timestamp da última alteração |
| `USUALTERACAO` | `usualteracao` | TEXT | Usuário da última alteração |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```text
raw.mrl_promocaoitem
    └── staging.stg_mrl_promocaoitem
            └── dw.dim_produto_empresa  (CTE promoc_vigente — join com mrl_promocao)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-06-04 | Pipeline criado |
