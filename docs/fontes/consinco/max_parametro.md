# Pipeline: max_parametro

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAX_PARAMETRO` (Oracle) |
| Destino | `raw.max_parametro` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/max_parametro.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Parâmetros de configuração do sistema Consinco por loja e grupo. Usado para
leitura de configurações operacionais sem necessidade de acessar o ERP.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja (FK → max_empresa) |
| `PARAMETRO` | `parametro` | TEXT | Identificador do parâmetro |
| `GRUPO` | `grupo` | TEXT | Grupo ao qual o parâmetro pertence |
| `VALOR` | `valor` | TEXT | Valor configurado |
| `TIPODADO` | `tipodado` | TEXT | Tipo de dado do valor |
| `COMENTARIO` | `comentario` | TEXT | Descrição do parâmetro |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-27 | Pipeline criado |
