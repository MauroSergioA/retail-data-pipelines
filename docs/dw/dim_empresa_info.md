# dw.dim_empresa_info

## Descrição

Dimensão de lojas e empresas da rede de varejo. Inclui todas as unidades —
ativas e inativas. Nunca filtrar por `NOT IN (3, 4)`.

Para obter apenas lojas ativas: `WHERE status = 'ATIVO'`.

## Linhagem

```
raw.max_empresa
    └── staging.stg_max_empresa ──────────┐
raw.vw_pdv                                │
    └── staging.stg_vw_pdv ──────────────┤
                                          └── dw.dim_empresa_info
```

## Colunas

### Identificação

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `empresa_id` | INTEGER | Chave primária — código da loja (nroempresa) |
| `divisao_id` | INTEGER | Código da divisão comercial |
| `desc_loja` | TEXT | Descrição padronizada: `NNN - CIDADE` ou `NNN - CIDADE L1/L2` |
| `razao_social` | TEXT | Razão social em maiúsculas |
| `empresa_razao_social` | TEXT | Código formatado + razão social: `NNN - RAZÃO SOCIAL` |
| `cnpj` | TEXT | CNPJ (14 dígitos sem pontuação) |
| `inscricao_estadual` | TEXT | Inscrição estadual |

### Endereço

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `endereco` | TEXT | Logradouro em maiúsculas |
| `bairro` | TEXT | Bairro em maiúsculas |
| `cep` | TEXT | CEP |
| `cidade` | TEXT | Cidade em maiúsculas |
| `uf` | TEXT | Estado em maiúsculas |
| `endereco_completo` | TEXT | Endereço + bairro + CEP + cidade/UF concatenados |

### Operação

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `metro_quadrado` | NUMERIC | Área da loja em m² |
| `seq_pessoa_empresa` | NUMERIC | Sequencial de pessoa jurídica |
| `segmento_principal` | NUMERIC | Código do segmento principal |
| `aberto_sabado` | TEXT | Funciona aos sábados: `SIM` ou `NÃO` |
| `aberto_domingo` | TEXT | Funciona aos domingos: `SIM` ou `NÃO` |
| `meta_margem_lucro` | NUMERIC | Meta de margem de lucro (%) |
| `meta_dia_estoque` | NUMERIC | Meta de dias de estoque |
| `status` | TEXT | Status da loja: `ATIVO` ou `INATIVO` |
| `dta_fechamento_fiscal` | DATE | Data de fechamento fiscal (lojas inativas) |
| `inicio_estoque` | DATE | Data de início do controle de estoque |
| `nro_nsu_nf` | INTEGER | Último NSU de nota fiscal |
| `total_pdv_ativo` | INTEGER | Quantidade de checkouts ativos na loja |

### Códigos Gerais de Operação (CGO)

Cada loja tem CGOs distintos por tipo de movimentação — usados para filtrar
registros de estoque nas tabelas de movimentação do Consinco.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `cgo_baixa_saida_pdv` | INTEGER | Baixa de saída PDV |
| `cgo_transf_loc_ori` | INTEGER | Transferência — local de origem |
| `cgo_transf_loc_dest` | INTEGER | Transferência — local de destino |
| `cgo_baixa_producao` | INTEGER | Baixa de produção |
| `cgo_entr_producao` | INTEGER | Entrada de produção |
| `cgo_baixa_inventario` | INTEGER | Baixa de inventário |
| `cgo_entr_inventario` | INTEGER | Entrada de inventário |
| `cgo_emiss_nf_venda` | INTEGER | Emissão de NF de venda |
| `cgo_entr_transf` | INTEGER | Entrada de transferência |
| `cgo_dev_fornec` | INTEGER | Devolução ao fornecedor |
| `cgo_entr_transf_prod` | INTEGER | Entrada de transferência de produção |
| `cgo_sai_transf_prod` | INTEGER | Saída de transferência de produção |
| `cgo_baixa_perda` | INTEGER | Baixa de perda |
| `cgo_ajuste_custo` | INTEGER | Ajuste de custo |
| `cgo_ajuste_custo_redu` | INTEGER | Redução de custo |

### Auditoria

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `loaded_at` | TIMESTAMP | Timestamp da última carga do pipeline Hop |

## Regras de transformação

### desc_loja

```sql
CASE
    WHEN nro_empresa = 1
        THEN '001 - MATRIZ'
    WHEN total_lojas_na_cidade > 1
        THEN LPAD(nro_empresa, 3, '0') || ' - ' || cidade || ' L' || rank_na_cidade
    ELSE
        LPAD(nro_empresa, 3, '0') || ' - ' || cidade
END
```

A empresa 1 (MATRIZ) é sempre `001 - MATRIZ`, independente da cidade.
O sufixo `L1/L2` é atribuído quando há mais de uma loja na mesma cidade,
ordenado pelo `nro_empresa` (menor = L1).
A contagem de lojas por cidade **exclui** a empresa 1 para não inflar cidades.

### cnpj

```sql
LPAD(nro_cnpj::TEXT, 12, '0') || LPAD(dig_cnpj::TEXT, 2, '0')
```

### status

Valores de origem `A`/`I` convertidos para `ATIVO`/`INATIVO`.

### aberto_sabado / aberto_domingo

Indicadores `S`/`N` convertidos para `SIM`/`NÃO`.

### total_pdv_ativo

Contagem de checkouts com `status_pdv = 'ATIVO'` em `stg_vw_pdv`, agrupada por loja.
O `status_pdv` é derivado da coluna `ativo` da view Oracle `CONSINCOMONITOR.VW_PDV`.
Lojas sem PDV cadastrado retornam `NULL` (LEFT JOIN).

## Testes dbt

| Coluna | Testes |
|--------|--------|
| `empresa_id` | `not_null`, `unique` |
| `desc_loja` | `not_null`, `unique` |
| `status` | `not_null`, `accepted_values: ['ATIVO', 'INATIVO']` |
| `loaded_at` | `not_null` |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-22 | Modelo criado com desc_loja, CNPJ formatado e endereço completo |
| 2026-05-27 | Coluna loaded_at adicionada; correção da contagem de cidades (empresa 1 excluída) |
| 2026-05-29 | Refatoração: status humanizado (ATIVO/INATIVO), aberto_sabado/domingo (SIM/NÃO), adição de empresa_razao_social, total_pdv_ativo e colunas CGO; nova linhagem via stg_vw_pdv |
