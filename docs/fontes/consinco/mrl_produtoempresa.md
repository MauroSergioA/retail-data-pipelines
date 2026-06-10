# Pipeline: mrl_produtoempresa

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MRL_PRODUTOEMPRESA` (Oracle) |
| Destino | `raw.mrl_produtoempresa` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/mrl_produtoempresa.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Parâmetros operacionais e posições de estoque de produto por loja. Chave composta
`seqproduto + nroempresa`. Esta tabela é a origem do status de compra de um produto
em uma loja específica (`statuscompra`) — informação que não existe em `map_produto`.

Três colunas com sufixo `_DEPRECIADA` foram mantidas na extração intencionalmente
para fins de rastreabilidade histórica.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPRODUTO` | `seqproduto` | INTEGER | Código do produto — parte da chave |
| `NROEMPRESA` | `nroempresa` | INTEGER | Código da loja — parte da chave |
| `STATUSCOMPRA` | `statuscompra` | TEXT | Status de compra do produto na loja: A = ativo, I = inativo |
| `LOCENTRADA` | `locentrada` | INTEGER | Local de entrada de estoque |
| `LOCSAIDA` | `locsaida` | INTEGER | Local de saída de estoque |
| `ESTQLOJA` | `estqloja` | NUMERIC | Saldo de estoque no salão |
| `ESTQDEPOSITO` | `estqdeposito` | NUMERIC | Saldo de estoque no depósito |
| `ESTQTROCA` | `estqtroca` | NUMERIC | Saldo de estoque em troca |
| `ESTQALMOXARIFADO` | `estqalmoxarifado` | NUMERIC | Saldo de estoque no almoxarifado |
| `ESTQOUTRO` | `estqoutro` | NUMERIC | Outros saldos de estoque |
| `ESTQEMPRESA` | `estqempresa` | NUMERIC | Estoque total consolidado da empresa |
| `QTDPENDPEDCOMPRA_DEPRECIADA` | `qtdpendpedcompra_depreciada` | NUMERIC | Qtd. pendente de pedido de compra (depreciada) |
| `QTDPENDPEDEXPED_DEPRECIADA` | `qtdpendpedexped_depreciada` | NUMERIC | Qtd. pendente de expedição (depreciada) |
| `QTDPEDRECTRANSITO_DEPRECIADA` | `qtdpedrectransito_depreciada` | NUMERIC | Qtd. em trânsito de transferência (depreciada) |
| `MEDVDIAGERAL` | `medvdiageral` | NUMERIC | Média de venda diária geral |
| `MEDVDIAFORAPROMOC` | `medvdiaforapromoc` | NUMERIC | Média de venda diária fora de promoção |
| `CMULTCUSLIQUIDOEMP` | `cmultcusliquidoemp` | NUMERIC | Custo líquido unitário da empresa |
| `CMULTVLRNF` | `cmultvlrnf` | NUMERIC | Valor de NF unitário |
| `INDGERARUPTURA` | `indgeraruptura` | TEXT | Indica se o produto gera ruptura |
| `DTAULTMOVTACAO` | `dtaultmovtacao` | DATE | Data da última movimentação |
| `DTAULTMOVENTRADA` | `dtaultmoventrada` | DATE | Data da última entrada |
| `DTAULTMOVSAIDA` | `dtaultmovsaida` | DATE | Data da última saída |
| `DTAULTENTRADA` | `dtaultentrada` | DATE | Data da última entrada de compra |
| `QTDULTENTRADA` | `qtdultentrada` | NUMERIC | Quantidade da última entrada |
| `DTAULTCOMPRA` | `dtaultcompra` | DATE | Data da última ordem de compra |
| `QTDULTCOMPRA` | `qtdultcompra` | NUMERIC | Quantidade da última compra |
| `SEQNFULTENTRCOMPRA` | `seqnfultentrcompra` | INTEGER | Seq. da última NF de entrada |
| `SEQNFULTENTRCOMPRAGERAL` | `seqnfultentrcomprageral` | INTEGER | Seq. da última NF de entrada geral |
| `DTAULTVENDA` | `dtaultvenda` | DATE | Data da última venda |
| `QTDULTVENDA` | `qtdultvenda` | NUMERIC | Quantidade da última venda |
| `DTAULTINVFISICO` | `dtaultinvfisico` | DATE | Data do último inventário físico |
| `QTDULTIMOINVENTARIO` | `qtdultimoinventario` | NUMERIC | Quantidade do último inventário |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```text
raw.mrl_produtoempresa
    └── staging.stg_mrl_produtoempresa
            └── dw.dim_produto_empresa
```

**Nota:** `dias_estoque`, `dias_sem_compra`, `dias_sem_venda` e `dias_sem_venda_desde_ultima_entrada` são calculados diretamente no staging (não no dw) para ficarem disponíveis a qualquer consumidor da staging.

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-06-04 | Staging `stg_mrl_produtoempresa` e `dim_produto_empresa` implementados |
| 2026-05-27 | Pipeline criado; colunas _DEPRECIADA mantidas intencionalmente |
