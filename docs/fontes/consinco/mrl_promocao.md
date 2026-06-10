# Pipeline: mrl_promocao

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MRL_PROMOCAO` (Oracle) |
| Destino | `raw.mrl_promocao` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mrl_promocao.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cabeçalho das promoções da rede. Chave composta `seqpromocao + nroempresa + nrosegmento + centralloja`.
Contém nome, tipo, vigência (`dtainicio`/`dtafim`) e indicadores da promoção. Promoções passadas
não mudam — novas são adicionadas continuamente. Carga full é viável pois o volume total é pequeno.

## Filtros na extração

Nenhum — extração completa. O filtro de vigência (`dtainicio <= CURRENT_DATE AND dtafim >= CURRENT_DATE`)
é aplicado nos modelos dw consumidores.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPROMOCAO` | `seqpromocao` | INTEGER | Código da promoção — parte da chave |
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja — parte da chave |
| `NROSEGMENTO` | `nrosegmento` | INTEGER | Número do segmento — parte da chave |
| `CENTRALLOJA` | `centralloja` | TEXT | Origem: C = central, L = loja — parte da chave |
| `NRODIVISAO` | `nrodivisao` | INTEGER | Divisão comercial |
| `PROMOCAO` | `promocao` | TEXT | Nome/descrição da promoção |
| `TIPOPROMOC` | `tipopromoc` | TEXT | Tipo da promoção |
| `DTAINICIO` | `dtainicio` | DATE | Data de início da vigência |
| `DTAFIM` | `dtafim` | DATE | Data de fim da vigência |
| `INDPREVALECEPRECO` | `indprevalecepreco` | TEXT | S/N — preço promo prevalece sobre o normal |
| `INDSEGMENTOPRINC` | `indsegmentoprinc` | TEXT | S/N — promoção do segmento principal |
| `SEQENCARTE` | `seqencarte` | INTEGER | FK para encarte vinculado. NULL quando não é encarte |
| `DTAGERACAOPROMOC` | `dtageracaopromoc` | DATE | Data de geração da promoção |
| `DTAHORAINCLUSAO` | `dtahorainclusao` | TIMESTAMP | Timestamp de inclusão |
| `DTAHORAALTERACAO` | `dtahoraalteracao` | TIMESTAMP | Timestamp da última alteração |
| `USUINCLUSAO` | `usuinclusao` | TEXT | Usuário que incluiu |
| `USUALTERACAO` | `usualteracao` | TEXT | Usuário da última alteração |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```text
raw.mrl_promocao
    └── staging.stg_mrl_promocao
            └── dw.dim_produto_empresa  (CTE promoc_vigente — join com mrl_promocaoitem)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-06-04 | Pipeline criado |
