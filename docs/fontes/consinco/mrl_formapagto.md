# Pipeline: mrl_formapagto

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MRL_FORMAPAGTO` (Oracle) |
| Destino | `raw.mrl_formapagto` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mrl_formapagto.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de formas de pagamento do Consinco. Referenciado em `maxv_abcdistribbase`
pela coluna `nroformapagto`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NROFORMAPAGTO` | `nroformapagto` | INTEGER | Código da forma de pagamento — chave primária |
| `FORMAPAGTO` | `formapagto` | TEXT | Descrição da forma de pagamento |
| `ESPECIEFORMAPAGTO` | `especieformapagto` | TEXT | Espécie da forma de pagamento |
| `STATUSFORMAPAGTO` | `statusformapagto` | TEXT | Status |
| `NROFORMAPAGTOECF` | `nroformapagtoecf` | INTEGER | Código ECF da forma de pagamento |
| `CODESPECIE` | `codespecie` | TEXT | Código da espécie financeira |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
