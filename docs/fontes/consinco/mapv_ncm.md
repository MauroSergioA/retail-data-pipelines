# Pipeline: mapv_ncm

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAPV_NCM` (Oracle) |
| Destino | `raw.mapv_ncm` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mapv_ncm.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de NCM (Nomenclatura Comum do Mercosul). Extração via `SELECT *` —
colunas serão documentadas ao construir o modelo staging.

## Colunas extraídas

Extração completa via `SELECT *`. Colunas a documentar na próxima sessão de
desenvolvimento.

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
