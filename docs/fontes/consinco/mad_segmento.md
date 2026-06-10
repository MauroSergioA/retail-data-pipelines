# Pipeline: mad_segmento

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAD_SEGMENTO` (Oracle) |
| Destino | `raw.mad_segmento` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mad_segmento.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de segmentos comerciais por divisão. Cada loja possui um segmento
principal (`nrosegmentoprinc` em `max_empresa`). Usado para enriquecer análises
segmentadas e para o filtro correto de dados em `mrl_prodempseg`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NRODIVISAO` | `nrodivisao` | INTEGER | Número da divisão comercial |
| `NROSEGMENTO` | `nrosegmento` | INTEGER | Número do segmento |
| `DESCSEGMENTO` | `descsegmento` | TEXT | Descrição do segmento |
| `STATUS` | `status` | TEXT | Status do segmento |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
