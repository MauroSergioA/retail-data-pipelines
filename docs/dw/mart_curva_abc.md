# dw.mart_curva_abc

## Descrição

Curva ABC de produtos por loja. Grain: `produto_id × empresa_id`.

Calculada sobre os últimos 12 meses a partir da data mais recente em `fato_venda` — usar `MAX(dta_venda)` em vez de `CURRENT_DATE` garante funcionamento correto mesmo durante cargas históricas incompletas.

Inclui apenas produtos com receita líquida positiva no período (`HAVING SUM(vlr_venda_liq) > 0`).

Recalculada semanalmente (todo domingo às 01:00) — a curva de 12 meses não muda de forma relevante dia a dia.

## Três dimensões de classificação

| Dimensão | Universo de comparação | Uso típico |
|---|---|---|
| Por empresa | Produto vs. todos os produtos da mesma loja | Gestão de estoque por loja |
| Por categoria × empresa | Produto vs. todos os produtos da mesma categoria na loja | Análise de ruptura |
| Por rede | Produto vs. todos os produtos de todas as lojas | Negociação com fornecedor |

Cada dimensão é classificada por **valor** (receita líquida) e por **quantidade** líquida vendida.

Thresholds: A ≤ 80%, B ≤ 95%, C > 95% do acumulado.

## Linhagem

```text
dw.fato_venda        ─┐
dw.dim_produto_info  ─┴─→ dw.mart_curva_abc
```

## Colunas

### Chaves

| Coluna | Tipo | Descrição |
|---|---|---|
| `empresa_id` | INTEGER | Código da loja (FK `dim_empresa_info`) |
| `produto_id` | INTEGER | Código do produto (FK `dim_produto_info`) |
| `familia_id` | INTEGER | Família do produto |
| `categoria_id` | INTEGER | Categoria nível 1 do produto |

### Métricas do período

| Coluna | Descrição |
|---|---|
| `receita_liq` | Receita líquida do produto na loja nos últimos 12 meses |
| `quantidade_liq` | Quantidade líquida vendida na loja nos últimos 12 meses |
| `receita_liq_rede` | Receita líquida consolidada em todas as lojas |
| `quantidade_liq_rede` | Quantidade líquida consolidada em todas as lojas |

### Classificações ABC

| Coluna | Descrição |
|---|---|
| `pct_acum_valor_empresa` | % acumulado de receita dentro da loja |
| `curva_abc_valor_empresa` | Classificação A/B/C por valor na loja |
| `pct_acum_qtd_empresa` | % acumulado de quantidade dentro da loja |
| `curva_abc_qtd_empresa` | Classificação A/B/C por quantidade na loja |
| `pct_acum_valor_categoria` | % acumulado de receita dentro da categoria na loja |
| `curva_abc_valor_categoria` | Classificação A/B/C por valor na categoria |
| `pct_acum_qtd_categoria` | % acumulado de quantidade dentro da categoria na loja |
| `curva_abc_qtd_categoria` | Classificação A/B/C por quantidade na categoria |
| `pct_acum_valor_rede` | % acumulado de receita na rede |
| `curva_abc_valor_rede` | Classificação A/B/C por valor na rede |
| `pct_acum_qtd_rede` | % acumulado de quantidade na rede |
| `curva_abc_qtd_rede` | Classificação A/B/C por quantidade na rede |

### Referência

| Coluna | Descrição |
|---|---|
| `periodo_inicio` | Início da janela de 12 meses |
| `periodo_fim` | Fim da janela — `MAX(dta_venda)` no momento do build |
| `carregado_em` | Timestamp do build dbt |

## Testes aplicados

| Teste | Coluna | Arquivo |
|---|---|---|
| `not_null` | `empresa_id`, `produto_id`, `carregado_em` | `_dw.yml` |
| Grain único | `empresa_id × produto_id` | `tests/mart_curva_abc_grain_unico.sql` |

## Resultado esperado (distribuição Pareto)

| Curva | % produtos | % receita |
|---|---|---|
| A | ~10% | ~80% |
| B | ~30% | ~15% |
| C | ~60% | ~5% |
