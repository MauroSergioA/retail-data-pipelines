# dw.dim_produto_empresa

## Descrição

Snapshot operacional de produto por loja. Grain: `produto_id × empresa_id` — uma linha por
combinação produto/loja (~842k linhas, 12 lojas × ~70k produtos ativos).

Não desnormaliza atributos descritivos de produto ou loja — usar relacionamentos com
`dim_produto_info` e `dim_empresa_info` no Power BI. Apenas `status_empresa` e
`fornecedor_principal_id` são incluídos como conveniência de filtro e FK.

Inclui dados de quatro fontes distintas, todas unidas pelo par `produto_id × empresa_id`:

| Fonte | O que traz |
| --- | --- |
| `mrl_produtoempresa` | Estoques, médias de venda, custos, datas de movimentação, dias calculados |
| `mrl_prodempseg` | Preços (3 tipos), preços promo, margem, status de venda — pelo segmento principal da loja |
| `mrl_promocao` + `mrl_promocaoitem` | Promoção vigente hoje: flag, preço, desconto, datas |
| `dim_produto_info` | `fornecedor_principal_id` (FK para `dim_fornecedor_info`) |

## Linhagem

```text
raw.mrl_produtoempresa   → staging.stg_mrl_produtoempresa  ─┐
raw.mrl_prodempseg       → staging.stg_mrl_prodempseg       │
raw.mrl_promocao         → staging.stg_mrl_promocao         ├─→ dw.dim_produto_empresa
raw.mrl_promocaoitem     → staging.stg_mrl_promocaoitem     │
dw.dim_produto_info      ────────────────────────────────────┘
dw.dim_empresa_info      (status_empresa + segmento_principal)
```

## Colunas

### Chaves

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `produto_id` | INTEGER | FK para `dim_produto_info` |
| `empresa_id` | INTEGER | FK para `dim_empresa_info` |
| `fornecedor_principal_id` | INTEGER | FK para `dim_fornecedor_info` |

### Status

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `status_empresa` | TEXT | `ATIVA` ou `INATIVA` — conveniência de filtro sem join com `dim_empresa_info` |
| `status_compra` | TEXT | `ATIVO`, `INATIVO` ou `NÃO INFORMADO` — ativação do produto para compra nesta loja |
| `status_venda` | TEXT | `ATIVO`, `INATIVO` ou `NÃO INFORMADO` — ativação do produto para venda nesta loja |
| `gera_ruptura` | TEXT | `SIM` ou `NÃO` — produto entra no cálculo de ruptura |

### Promoção vigente

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `ind_em_promoc` | TEXT | `SIM` ou `NÃO` — produto tem promoção ativa hoje |
| `promocao_vigente_id` | INTEGER | FK para `mrl_promocao`. NULL quando sem promoção |
| `preco_promoc_vigente` | NUMERIC | Preço promocional vigente. NULL quando sem promoção |
| `perc_desconto_promoc` | NUMERIC | Percentual de desconto da promoção vigente |
| `dta_inicio_promoc` | DATE | Início da promoção vigente (usa data do item quando disponível) |
| `dta_fim_promoc` | DATE | Fim da promoção vigente (usa data do item quando disponível) |

### Estoques

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `local_entrada_id` | INTEGER | Local de entrada padrão de estoque (FK `mrl_local`) |
| `local_saida_id` | INTEGER | Local de saída padrão de estoque (FK `mrl_local`) |
| `estoque_loja` | NUMERIC | Saldo no salão da loja |
| `estoque_deposito` | NUMERIC | Saldo no depósito |
| `estoque_troca` | NUMERIC | Saldo em troca |
| `estoque_almoxarifado` | NUMERIC | Saldo no almoxarifado |
| `estoque_outro` | NUMERIC | Saldo em outros locais |
| `estoque_empresa` | NUMERIC | Estoque total consolidado (todos os locais) |
| `qtd_pedido_compra_pendente` | NUMERIC | Qtd. pendente em pedidos de compra (coluna depreciada no Oracle) |
| `qtd_pedido_expedicao_pendente` | NUMERIC | Qtd. pendente em expedição (depreciada) |
| `qtd_recebimento_transito` | NUMERIC | Qtd. em trânsito (depreciada) |

### Médias e métricas

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `media_venda_diaria` | NUMERIC | Média de venda diária geral (inclui períodos promocionais) |
| `media_venda_diaria_fora_promo` | NUMERIC | Média de venda diária fora de promoção |
| `dias_estoque` | NUMERIC | `estoque_loja ÷ media_venda_diaria`. NULL quando média = 0 |

### Preços (segmento principal da loja)

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `preco_base_normal` | NUMERIC | Preço base normal |
| `preco_ger_normal` | NUMERIC | Preço gerado praticado normal |
| `preco_valido_normal` | NUMERIC | Preço válido atual — o preço efetivamente em vigor |
| `preco_ger_promoc` | NUMERIC | Preço gerado em promoção |
| `preco_valido_promoc` | NUMERIC | Preço válido em promoção |
| `margem_lucro` | NUMERIC | Percentual de margem de lucro |
| `custo_liq_precificacao` | NUMERIC | Custo líquido base para precificação do dia |
| `motivo_preco_valido` | TEXT | Motivo da última alteração do preço válido (auditoria) |
| `dta_geracao_preco` | DATE | Data de geração do preço |
| `dta_validacao_preco` | DATE | Data de validação do preço |
| `dta_hora_alteracao_preco` | TIMESTAMP | Timestamp da última alteração de preço |
| `dta_hora_alt_status_venda` | TIMESTAMP | Timestamp da última alteração do status de venda |
| `preco_ger_programado` | NUMERIC | Preço agendado para vigorar em data futura |
| `dta_preco_programado` | DATE | Data de ativação do preço programado |
| `ind_revisao_preco` | TEXT | `SIM` ou `NÃO` — produto está em processo de revisão de preço |
| `promocao_id` | INTEGER | FK para promoção vinculada no cadastro de preços |

### Custos

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `ultimo_custo_liquido` | NUMERIC | Último custo líquido registrado |
| `ultimo_valor_nf` | NUMERIC | Último valor de NF de entrada |

### Datas e quantidades

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `dta_ultima_movimentacao` | DATE | Data da última movimentação de estoque (qualquer tipo) |
| `dta_ultima_movimentacao_entrada` | DATE | Data da última movimentação de entrada |
| `dta_ultima_movimentacao_saida` | DATE | Data da última movimentação de saída |
| `dta_ultima_entrada` | DATE | Data da última entrada por NF |
| `qtd_ultima_entrada` | NUMERIC | Quantidade da última entrada por NF |
| `dta_ultima_compra` | DATE | Data do último pedido de compra emitido |
| `qtd_ultima_compra` | NUMERIC | Quantidade do último pedido de compra |
| `dias_sem_compra` | INTEGER | `CURRENT_DATE - dta_ultima_compra`. NULL quando nunca houve compra |
| `dta_ultima_venda` | DATE | Data da última venda |
| `qtd_ultima_venda` | NUMERIC | Quantidade da última venda |
| `dias_sem_venda` | INTEGER | `CURRENT_DATE - dta_ultima_venda`. NULL quando nunca houve venda |
| `dias_sem_venda_desde_ultima_entrada` | INTEGER | Dias desde o maior entre `dta_ultima_venda` e `dta_ultima_movimentacao_entrada` |
| `dta_ultimo_inventario` | DATE | Data do último inventário físico |
| `qtd_ultimo_inventario` | NUMERIC | Quantidade contada no último inventário |

### Auditoria

| Coluna | Tipo | Descrição |
| --- | --- | --- |
| `carregado_em` | TIMESTAMP | Timestamp da última carga da `mrl_produtoempresa` via Hop |

## Regras de transformação

### Join de preço por segmento

O preço de um produto varia por segmento. O join correto usa o segmento principal de cada loja:

```sql
LEFT JOIN stg_mrl_prodempseg pr
    ON  pr.produto_id    = pe.produto_id
    AND pr.empresa_id    = pe.empresa_id
    AND pr.segmento_id   = e.segmento_principal   -- segmento correto da loja
    AND pr.qtd_embalagem = 1
```

**Nunca** filtrar por `segmento_id = 1` fixo — exclui lojas com segmento diferente de 1.

### Promoção vigente (deduplicação)

Pode haver mais de uma promoção ativa para o mesmo produto/loja simultaneamente. O modelo
usa `DISTINCT ON` para selecionar a promoção que termina primeiro:

```sql
SELECT DISTINCT ON (produto_id, empresa_id, segmento_id)
    ...
ORDER BY produto_id, empresa_id, segmento_id,
         COALESCE(dta_fim_item, dta_fim) ASC
```

A data efetiva usa `COALESCE(item.dta_inicio_item, cabecalho.dta_inicio)` — o item pode
sobrescrever as datas do cabeçalho.

## Testes dbt

| Coluna | Testes |
| --- | --- |
| `produto_id` | `not_null` |
| `empresa_id` | `not_null` |
| `status_compra` | `not_null`, `accepted_values` (`ATIVO`, `INATIVO`, `NÃO INFORMADO`) |
| `carregado_em` | `not_null` |

## Pendente (próximas iterações)

- `fornecedor_ult_entrada_id` — requer extração de `mlf_notafiscal`
- `leadtime_entrega` — calculado de `mlf_notafiscal` (`dta_entrada - dta_emissao` por fornecedor), mais confiável que o campo manual do ERP

## Changelog

| Data | Alteração |
| --- | --- |
| 2026-06-04 | Adicionados preços (`mrl_prodempseg`), promoção vigente (`mrl_promocao` + `mrl_promocaoitem`) e `fornecedor_principal_id` |
| 2026-06-04 | Modelo criado — estoques, médias de venda, custos, datas e dias calculados |
