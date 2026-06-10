# Pipeline: maf_fornecdivisao

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAF_FORNECDIVISAO` (Oracle) |
| Destino | `raw.maf_fornecdivisao` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/maf_fornecdivisao.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de fornecedores por divisão comercial. Fonte única para a futura
`dim_fornecedor`. Contém prazos comerciais, condições de pagamento e
classificação ABC do fornecedor.

A tabela `maf_fornecedor` (dados cadastrais gerais como nome e CNPJ) não está
no escopo atual — os dados de `ge_pessoa` suprem essa necessidade via `seqpessoa`
quando necessário.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NRODIVISAO` | `nrodivisao` | INTEGER | Número da divisão comercial |
| `SEQFORNECEDOR` | `seqfornecedor` | INTEGER | Código sequencial do fornecedor — chave natural |
| `PZOMEDVISITAREP` | `pzomedvisitarep` | NUMERIC | Prazo médio de visita do representante (dias) |
| `PZOMEDENTREGA` | `pzomedentrega` | NUMERIC | Prazo médio de entrega (dias) |
| `PZOMEDATRASO` | `pzomedatraso` | NUMERIC | Prazo médio de atraso na entrega (dias) |
| `PZOPAGAMENTO` | `pzopagamento` | NUMERIC | Prazo de pagamento (dias) |
| `NROCONDPAGDEV` | `nrocondpagdev` | INTEGER | Código da condição de pagamento para devolução |
| `NROFORMAPAGTODEV` | `nroformapagtodev` | INTEGER | Código da forma de pagamento para devolução |
| `STATUSGERAL` | `statusgeral` | TEXT | Status geral do fornecedor |
| `CLASSIFCOMERCABC` | `classifcomercabc` | TEXT | Classificação comercial ABC |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.maf_fornecdivisao
    └── staging.stg_maf_fornecdivisao   (a criar)
            └── dw.dim_fornecedor        (a criar)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-27 | Pipeline criado |
