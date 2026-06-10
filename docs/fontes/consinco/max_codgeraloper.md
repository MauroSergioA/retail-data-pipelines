# Pipeline: max_codgeraloper

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAX_CODGERALOPER` (Oracle) |
| Destino | `raw.max_codgeraloper` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/max_codgeraloper.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de Códigos Gerais de Operação (CGO). Define o tipo, aplicação e
sentido (entrada/saída) de cada operação no Consinco.

Os CGOs usados nas vendas PDV são: `800`, `810`, `820`, `828` (venda) e
`202` (devolução). Cada loja possui seus próprios CGOs por tipo de movimento,
armazenados em `dim_empresa_info`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `CODGERALOPER` | `codgeraloper` | INTEGER | Código da operação — chave primária |
| `DESCRICAO` | `descricao` | TEXT | Descrição da operação |
| `APLICACAO` | `aplicacao` | TEXT | Aplicação do CGO (PDV, estoque, fiscal, etc.) |
| `TIPCGO` | `tipcgo` | TEXT | Tipo: S = saída, E = entrada |
| `TIPUSO` | `tipuso` | TEXT | Tipo de uso do CGO |
| `STATUS` | `status` | TEXT | Status do CGO |
| `CODESPECIEFIN` | `codespeciefin` | TEXT | Código da espécie financeira vinculada |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
