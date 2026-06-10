# Pipeline: map_famembalagem

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAP_FAMEMBALAGEM` (Oracle) |
| Destino | `raw.map_famembalagem` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/map_famembalagem.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Embalagens disponíveis por família de produto. Define as unidades de medida
e quantidades de embalagem válidas para os produtos de cada família.
Referenciada nas funções Oracle de cálculo de custo (`FC5_*`) usadas em
`maxv_abcdistribbase`.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQFAMILIA` | `seqfamilia` | INTEGER | Código da família (FK → map_familia) |
| `QTDEMBALAGEM` | `qtdembalagem` | NUMERIC | Quantidade de unidades da embalagem |
| `EMBALAGEM` | `embalagem` | TEXT | Descrição da embalagem (UND, CX, FD, etc.) |
| `QTDUNIDEMB` | `qtdunidemb` | NUMERIC | Quantidade de unidades dentro da embalagem |
| `PESOBRUTO` | `pesobruto` | NUMERIC | Peso bruto da embalagem em kg |
| `STATUS` | `status` | TEXT | Status da embalagem |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
