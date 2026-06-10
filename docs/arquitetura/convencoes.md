# Convenções do Projeto

## Nomenclatura — modelos dbt

| Camada | Prefixo | Exemplo |
|--------|---------|---------|
| Staging | `stg_` + nome da tabela Oracle | `stg_max_empresa` |
| Dimensão | `dim_` + nome da entidade | `dim_empresa_info` |
| Fato | `fato_` + nome da entidade | `fato_venda` |

Nomes em snake_case, sempre em português descritivo.

---

## Nomenclatura — colunas dbt

Todas as colunas no dw usam snake_case em português.

| Prefixo | Significado | Exemplo |
|---------|-------------|---------|
| `nro_` | Número/código | `nro_empresa`, `nro_docto` |
| `seq_` | Sequencial | `seq_produto`, `seq_operador` |
| `cod_` | Código de operação | `cod_geral_oper` |
| `dta_` | Data | `dta_venda`, `dta_hora_venda` |
| `vlr_` | Valor monetário | `vlr_venda_liq`, `vlr_lucro` |
| `qtd_` | Quantidade | `qtd_venda_liq`, `qtd_devol` |
| `desc_` | Descrição textual | `desc_loja` |
| `ind_` | Indicador (S/N) | `ind_aberto_sabado` |

Colunas de auditoria: `loaded_at` (timestamp da carga Hop) — sempre presente.

---

## Nomenclatura — pipelines Hop

Arquivos `.hpl` nomeados igual à tabela Oracle de origem, em minúsculas:

```
extract/consinco/max_empresa.hpl          → raw.max_empresa
extract/consinco/maxv_abcdistribbase.hpl  → raw.maxv_abcdistribbase
```

Transforms dentro do pipeline seguem o padrão:

| Transform | Tipo | Nome |
|-----------|------|------|
| Fonte Oracle | TableInput | `src_<tabela>` |
| Timestamp de carga | SystemInfo | `sys_loaded_at` |
| Destino PostgreSQL | TableOutput | `raw_<tabela>` |

---

## Padrões dbt

### Materialização por camada

```yaml
staging:
  +materialized: view     # sem custo de storage, sempre atualizado
dw:
  +materialized: table    # dimensões
  # fatos usam incremental individualmente
```

### Schemas sem prefixo

O macro `generate_schema_name` está configurado para usar o `custom_schema_name` diretamente,
sem prefixar o target schema. Resultado: `staging` (não `dw_staging`).

### Testes padrão

Toda coluna que é chave primária ou parte de chave composta deve ter `not_null` + `unique`.
Colunas de status com valores conhecidos devem ter `accepted_values`.
Todo modelo deve ter `not_null` em `loaded_at`.

### Humanização de valores

Campos de status e indicadores do Consinco usam códigos de 1 caractere. No dbt,
esses valores são sempre convertidos para texto legível na camada `dw`:

| Padrão Oracle | Valor dw | Aplicação |
|---------------|----------|-----------|
| `'A'` / `'I'` | `'ATIVO'` / `'INATIVO'` | Status de lojas, fornecedores, marcas |
| `'S'` / `'N'` | `'SIM'` / `'NÃO'` | Indicadores booleanos (aberto_sabado, pesavel, etc.) |

A conversão é feita com `CASE` no modelo `dw`, nunca no staging.
O staging preserva o valor original para rastreabilidade.

### `accepted_values` no dbt 1.12

A versão 1.12 exige os valores aninhados sob `arguments:`:

```yaml
data_tests:
  - accepted_values:
      arguments:
        values: ['A', 'I']
```

---

## Regras de negócio críticas

### Operações de venda válidas

```sql
cod_geral_oper IN (800, 810, 820, 828, 202)
```

Aplicado no SQL Oracle do Hop (reduz volume) e repetido no `fato_venda.sql` (segurança).

### Filtro de loja ativa

**Nunca** usar `NOT IN (3, 4)`. As lojas 3 e 4 têm dados históricos válidos.
Filtrar sempre via `status = 'A'` em `dim_empresa_info`.

### Segmento principal

**Nunca** filtrar `nrosegmento IN (1)` em `mrl_prodempseg`.
Usar sempre INNER JOIN com `max_empresa` pela coluna `nrosegmentoprinc`.

### desc_loja

Formato: `NNN - CIDADE` ou `NNN - CIDADE L1/L2` quando há mais de uma loja na mesma cidade.
MATRIZ (empresa 1): sempre `001 - MATRIZ` (hardcoded).
A contagem de lojas por cidade exclui a empresa 1.

---

## Convenções DAX (Power BI)

Padrão: `[Área].[TIPO]_[Nome][_Sufixo]`

| Tipo | Uso | Exemplo |
|------|-----|---------|
| `VLR` | Valor monetário | `Vendas.VLR_Faturamento` |
| `QTD` | Quantidade | `Vendas.QTD_Itens` |
| `PCT` | Percentual | `Vendas.PCT_Margem` |
| `IND` | Indicador booleano | `Vendas.IND_Meta_Atingida` |
| `DT` | Data | `Vendas.DT_UltimaVenda` |

Sufixo de período: `_PM` (período anterior), `_AA` (ano anterior), `_YTD` (acumulado do ano).

Exemplo: `Vendas.VLR_Faturamento_PM` = faturamento do período anterior.

---

## Documentação viva

- Atualizar a documentação no mesmo commit que altera o código
- Sem páginas stub — documentar apenas o que está implementado
- `README.md` mantém o roadmap e o status atual
- `docs/fontes/` e `docs/dw/` têm uma página por entidade com changelog
