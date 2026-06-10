# dw.dim_produto_info

## Descrição

Dimensão de produtos desnormalizada — une produto, família, categoria (hierarquia de 3 níveis),
marca, códigos EAN/balança e fornecedor principal em uma única tabela. Uma linha por produto,
sem filtro de status (a ativação por loja está em `mrl_produtoempresa.statuscompra`).

## Linhagem

```text
raw.map_produto      → staging.stg_map_produto     ─┐
raw.map_familia      → staging.stg_map_familia      │
raw.map_marca        → staging.stg_map_marca        ├─→ dw.dim_produto_info
raw.etlv_categoria   → staging.stg_etlv_categoria   │
raw.map_prodcodigo   → staging.stg_map_prodcodigo   │
raw.map_famfornec    → staging.stg_map_famfornec    ─┘
```

## Colunas

### Produto

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `produto_id` | INTEGER | Chave primária — código sequencial (seqproduto) |
| `produto` | TEXT | Descrição completa em maiúsculas |
| `produto_id_nome` | TEXT | Chave de exibição: `NNNNNN - PRODUTO` |
| `codigo_acesso` | TEXT | Códigos EAN e balança concatenados com ` ; ` (NULL quando ausente) |
| `data_inclusao` | DATE | Data de inclusão no cadastro Consinco |
| `carregado_em` | TIMESTAMP | Timestamp da última carga Hop |

### Família

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `familia_id` | INTEGER | Código sequencial da família |
| `familia` | TEXT | Descrição da família em maiúsculas |
| `familia_id_nome` | TEXT | Chave de exibição: `NNNNNN - FAMÍLIA` |
| `pesavel` | TEXT | Produto pesável: `SIM` ou `NÃO` |
| `permite_decimal` | TEXT | Aceita quantidade decimal: `SIM` ou `NÃO` |

### Categoria (hierarquia de 3 níveis)

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `categoria_id` | INTEGER | Código da categoria (nível 1) |
| `categoria` | TEXT | Descrição da categoria em maiúsculas |
| `categoria_id_nome` | TEXT | Chave de exibição: `NNNN - CATEGORIA` |
| `subcategoria_id` | INTEGER | Código da subcategoria (nível 2) |
| `subcategoria` | TEXT | Descrição da subcategoria (`NÃO DEFINIDA` quando ausente) |
| `subcategoria_id_nome` | TEXT | Chave de exibição: `NNNN - SUBCATEGORIA` |
| `grupo_id` | INTEGER | Código do grupo (nível 3; fallback para nível 2 quando ausente) |
| `grupo` | TEXT | Descrição do grupo (fallback para nível 2 quando ausente) |
| `grupo_id_nome` | TEXT | Chave de exibição: `NNNN - GRUPO` |
| `sk_categoria` | INTEGER | Chave surrogate da categoria completa no Consinco |
| `categoria_completa` | TEXT | Hierarquia completa concatenada em maiúsculas |
| `categoria_completa_id_nome` | TEXT | Chave de exibição: `NNNN - HIERARQUIA COMPLETA` |
| `perecivel` | TEXT | `PERECÍVEL` ou `NÃO PERECÍVEL` — derivado do categoria_id |

### Marca

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `marca_id` | INTEGER | Código sequencial da marca |
| `marca` | TEXT | Descrição da marca (`NÃO DEFINIDA` quando ausente) |
| `marca_id_nome` | TEXT | Chave de exibição: `NNNN - MARCA` |

### Fornecedor

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `fornecedor_principal_id` | INTEGER | Código do fornecedor principal da família |

## Regras de transformação

### Deduplicação de categoria

`etlv_categoria` tem uma linha por `(nrodivisao, seqfamilia)`. Para garantir
exatamente uma linha por família sem perder dados:

```sql
ROW_NUMBER() OVER (
    PARTITION BY seqfamilia
    ORDER BY
        CASE WHEN nrodivisao = 1 THEN 0 ELSE 1 END,
        nrodivisao
) = 1
```

Prioriza a divisão 1. Se a família não existir na divisão 1, usa a menor divisão
disponível — diferente do projeto anterior que filtrava `WHERE nrodivisao = 1`
e silenciosamente perdia famílias de outras divisões.

### codigo_acesso

Agrega todos os códigos EAN e balança em uma única string, ordenando EAN primeiro:

```sql
STRING_AGG(codigo_acesso, ' ; ' ORDER BY CASE tipo_codigo WHEN 'EAN' THEN 1 ELSE 2 END, codigo_acesso)
```

NULL quando o produto não possui código cadastrado dos tipos EAN ou BALANÇA.

### perecivel

Classificação baseada em `categoria_id` (nível 1 da hierarquia):

```sql
CASE WHEN categoria_id IN (1978, 2690, 2685, 1980, 1982) THEN 'PERECÍVEL'
     ELSE 'NÃO PERECÍVEL'
END
```

### fornecedor_principal_id

Filtrado de `stg_map_famfornec` onde `fornecedor_principal = 'SIM'`.
É um atributo de família — todos os produtos de uma mesma família
compartilham o mesmo fornecedor principal.

## Testes dbt

| Coluna | Testes |
| --- | --- |
| `produto_id` | `not_null`, `unique` |
| `carregado_em` | `not_null` |

## Changelog

| Data | Alteração |
| --- | --- |
| 2026-06-01 | Adicionados `codigo_acesso`, `fornecedor_principal_id` e colunas `_id_nome`. Deduplicação com ROW_NUMBER() em `etlv_categoria` |
| 2026-05-29 | Modelo criado — produto + família + marca + categoria desnormalizados |
