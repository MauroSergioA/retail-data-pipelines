# Pipeline: map_produto

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAP_PRODUTO` (Oracle) |
| Destino | `raw.map_produto` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/map_produto.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de produtos do Consinco. Contém descrição e vínculo com família de produto.

Não possui coluna STATUS — o status de ativação do produto por loja está em
`mrl_produtoempresa.statuscompra`. O cadastro de produto em si nunca é inativado;
o controle de compra e venda é feito na relação produto × empresa.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPRODUTO` | `seqproduto` | INTEGER | Código sequencial — chave primária |
| `DESCCOMPLETA` | `desccompleta` | TEXT | Descrição completa do produto |
| `SEQFAMILIA` | `seqfamilia` | INTEGER | Código da família (FK → map_familia) |
| `DTAHORINCLUSAO` | `dtahorinclusao` | TIMESTAMP | Data/hora de inclusão no cadastro |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.map_produto
    └── staging.stg_map_produto   (view — cast, rename, UPPER em desc_completa)
            └── dw.dim_produto_info
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-27 | Pipeline criado |
