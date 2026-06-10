# Pipeline: map_famfornec

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAP_FAMFORNEC` (Oracle) |
| Destino | `raw.map_famfornec` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/map_famfornec.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Vínculo entre família de produto e fornecedor. Indica o fornecedor principal
de cada família e se esse fornecedor indeniza avarias.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQFAMILIA` | `seqfamilia` | INTEGER | Código da família (FK → map_familia) |
| `SEQFORNECEDOR` | `seqfornecedor` | INTEGER | Código do fornecedor (FK → maf_fornecdivisao) |
| `PRINCIPAL` | `principal` | TEXT | Fornecedor principal da família: S/N |
| `INDINDENIZAVARIA` | `indindenizavaria` | TEXT | Indeniza avaria: S/N |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
