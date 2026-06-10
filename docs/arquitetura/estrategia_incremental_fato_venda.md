# Estratégia de Carregamento Incremental — fato_venda

## Contexto

A tabela de vendas é a maior e mais sensível do projeto. Ela alimenta diretamente os relatórios
operacionais no Power BI e precisa de atualizações frequentes ao longo do dia. Este documento
descreve as decisões arquiteturais tomadas para garantir dados frescos, sem duplicatas e com
histórico preservado.

---

## Arquitetura Geral (ELT)

```
Oracle (Consinco)
      │
      │  Hop — extração com janela rolling
      ▼
raw.maxv_abcdistribbase   ← buffer temporário (TRUNCATE + INSERT a cada run)
      │
      │  dbt — transformação incremental
      ▼
dw.fato_venda             ← histórico acumulado (nunca truncado)
```

O raw é um **buffer temporário** — contém apenas a janela recente.
O dw é o **acumulador histórico** — crescente, nunca truncado.

---

## Estratégia Hot / Cold

Dois tipos de execução, um único pipeline Hop com parâmetro `WINDOW_DAYS`.

| Tipo  | Frequência      | Janela Oracle                         | Propósito                              |
|-------|-----------------|---------------------------------------|----------------------------------------|
| Hot   | 4× por dia      | `DTAVDA = TRUNC(SYSDATE)` (hoje)     | Manter vendas do dia atualizadas       |
| Cold  | 1× madrugada    | `DTAVDA >= TRUNC(SYSDATE) - 5` (D-5) | Capturar correções retroativas         |

### Por que D-5 no cold?

Vendas raramente são corrigidas retroativamente. D-5 cobre:
- Correções do fim de semana processadas na segunda-feira
- Eventuais ajustes de caixa do dia anterior
- Margem de segurança sem impacto significativo de performance

---

## Fonte Oracle

### Tabela principal

`CONSINCO.MAXV_ABCDISTRIBBASE` — view analítica do Consinco com dados de venda PDV.

### Tabelas de apoio no JOIN Oracle

| Tabela                         | Papel                                         |
|-------------------------------|-----------------------------------------------|
| `MRL_CUSTODIA`                | Custo médio diário por produto por empresa    |
| `MAP_PRODUTO`                 | Cadastro de produtos (produto e produto-base) |
| `MAP_FAMDIVISAO`              | Família × divisão                             |
| `MAP_FAMEMBALAGEM`            | Embalagem padrão da família                   |
| `MAX_EMPRESA`                 | Cadastro de empresas/lojas                    |
| `MAX_DIVISAO`                 | Parâmetros da divisão                         |
| `MAP_PRODACRESCCUSTORELAC`    | Acréscimo de custo por produto relacionado    |

### Funções Oracle utilizadas

| Função                              | Resultado        | Observação                                      |
|------------------------------------|------------------|-------------------------------------------------|
| `FC5_AbcDistribLucratividade`      | `VLRLUCRO`       | ~50 parâmetros; lógica fiscal completa          |
| `FC5_ABCDISTRIBCUSTOBRUTO`         | `CTOBRUTOVDA`    | ~30 parâmetros; cálculo de custo bruto          |
| `fc5_divide`                       | divisão segura   | Utilitário interno                              |
| `fmrl_seqpromocProd`               | seq. promoção    | Identificação de promoção ativa no produto      |
| `F_RETACRESCCUSTORELACABC`         | % acréscimo      | Acréscimo de custo para produtos relacionados   |

**Decisão:** estas funções são chamadas **dentro do SQL do Hop** (roda no Oracle), não no dbt.
Reproduzir a lógica delas em PostgreSQL/dbt seria inviável sem meses de validação fiscal.
O resultado já calculado chega no raw como colunas numéricas normais.

---

## Granularidade

A query agrega por `GROUP BY`. Cada linha no raw/dw representa:

```
uma data de venda
× um documento (empresa + nrodocto + serie + checkout)
× um produto
× forma de pagamento
× segmento
× operador
× código de operação
```

O campo `DTAHORLANCTO` (timestamp da transação) é extraído bruto.
A coluna `hora_venda` é **derivada na staging** do dbt — não no Oracle.
Colunas `SYSDATE` e `HORACONSULTA` da query original são **descartadas** — substituídas por
`_loaded_at` do Hop SystemInfo.

---

## Colunas extraídas pelo Hop

As colunas marcadas com `*` são derivadas de `DTAHORLANCTO` na staging dbt, não no Oracle.

| Coluna Oracle             | Coluna staging dbt       | Tipo     |
|--------------------------|--------------------------|----------|
| `V.DTAVDA`               | `dta_venda`              | DATE     |
| `V.DTAHORLANCTO`         | `dta_hora_lancto`        | TIMESTAMP|
| `V.NROEMPRESA`           | `nro_empresa`            | INTEGER  |
| `V.CHECKOUT`             | `checkout`               | INTEGER  |
| `V.NRODOCTO`             | `nro_docto`              | BIGINT   |
| `V.SERIEDOCTO`           | `serie_docto`            | TEXT     |
| `A.SEQPRODUTO`           | `seq_produto`            | INTEGER  |
| `V.SEQOPERADOR`          | `seq_operador`           | INTEGER  |
| `V.NROFORMAPAGTO`        | `nro_forma_pagto`        | INTEGER  |
| `V.NROSEGMENTO`          | `nro_segmento`           | INTEGER  |
| `V.CODGERALOPER`         | `cod_geral_oper`         | INTEGER  |
| `SUM(V.QTDITEM)`         | `qtd_venda`              | NUMERIC  |
| `SUM(V.QTDDEVOLITEM)`    | `qtd_devolucao`          | NUMERIC  |
| `SUM(V.VLRITEM)`         | `vlr_venda`              | NUMERIC  |
| `SUM(V.VLRDEVOLITEM)`    | `vlr_devolucao`          | NUMERIC  |
| `SUM(V.VLRDESCITEM-...)` | `vlr_desconto`           | NUMERIC  |
| `SUM(VLRVENDAPROMOC...)`  | `vlr_venda_promoc`       | NUMERIC  |
| `SUM(FC5_Lucrat...)`     | `vlr_lucro`              | NUMERIC  |
| `SUM(FC5_CustoBruto...)` | `vlr_custo_bruto`        | NUMERIC  |
| `SUM(custoLiq...)`       | `vlr_custo_liquido`      | NUMERIC  |
| `_loaded_at` (Hop)       | `loaded_at`              | TIMESTAMP|

Coluna derivada na staging:
- `nro_documento` = `LPAD(nro_empresa,2,'0') || '-' || LPAD(nro_docto,9,'0') || '-' || serie_docto || '-' || LPAD(checkout,2,'0')`
- `hora_venda` = `EXTRACT(HOUR FROM dta_hora_lancto)`

---

## Chave única (unique_key)

Composta pelas colunas que formam o `GROUP BY` da query:

```
dta_venda + nro_empresa + checkout + nro_docto + serie_docto
+ seq_produto + nro_forma_pagto + nro_segmento + cod_geral_oper + seq_operador
```

O dbt usa essa chave para o `delete+insert` — apaga as linhas com essas combinações antes
de reinserir. Garante zero duplicata mesmo com múltiplos runs por dia.

---

## Parâmetro Hop: WINDOW_DAYS

O pipeline `maxv_abcdistribbase.hpl` recebe o parâmetro `WINDOW_DAYS`.

```sql
-- Trecho do TableInput Oracle
WHERE V.DTAVDA >= TRUNC(SYSDATE) - ${WINDOW_DAYS}
AND V.CODGERALOPER IN (800, 810, 820, 828, 202)
```

| Workflow Hop           | Valor de WINDOW_DAYS |
|-----------------------|----------------------|
| `run_hot.hwf`         | `0`                  |
| `run_cold.hwf`        | `5`                  |

---

## Como o dbt detecta a janela automaticamente

O modelo `fato_venda.sql` usa a data mínima do raw para saber qual janela processar:

```sql
{% if is_incremental() %}
WHERE dta_venda >= (
    SELECT MIN(dta_venda) FROM {{ source('consinco', 'maxv_abcdistribbase') }}
)
{% endif %}
```

- Run hot → raw tem só hoje → dbt toca só hoje no dw
- Run cold → raw tem D-5 → dbt toca D-5 no dw
- Histórico anterior ao D-5 no dw: **nunca tocado**

---

## Proteção contra duplicatas — resumo

```
Run 1 (08h)               Run 2 (12h)               Run 3 (18h)
────────────              ────────────              ────────────
Hop: TRUNCATE raw         Hop: TRUNCATE raw         Hop: TRUNCATE raw
     INSERT hoje               INSERT hoje               INSERT hoje
dbt: DELETE dw             dbt: DELETE dw             dbt: DELETE dw
     onde hoje                  onde hoje                  onde hoje
     INSERT raw →dw             INSERT raw →dw             INSERT raw →dw

dw: histórico preservado  dw: histórico preservado  dw: histórico preservado
    hoje = versão 08h          hoje = versão 12h          hoje = versão 18h
```

---

## Filtro de operações

Apenas operações de venda válidas são carregadas no dw:

```
CODGERALOPER IN (800, 810, 820, 828, 202)
```

Esse filtro é aplicado **no SQL Oracle do Hop** (reduz volume transferido) e **também no dbt**
como segunda camada de segurança.

---

## Modelos dbt a criar

| Modelo                        | Tipo        | Schema   | Observação                          |
|------------------------------|-------------|----------|-------------------------------------|
| `stg_maxv_abcdistribbase`    | view        | staging  | Cast + rename + derivações simples  |
| `fato_venda`                 | incremental | dw       | Upsert por unique_key composto      |

---

## Carga Histórica Inicial (one-time)

### Decisão: carregar tudo desde 01/08/2022

O dw deve ser o repositório completo. Filtros de janela de tempo (ex: "3 anos") pertencem
ao Power BI, não ao armazém. Razões:

- Dados mais antigos ficam disponíveis se o escopo de análise ampliar
- Os ~4 meses extras (ago–out/2022) não representam impacto relevante de storage
- Recarregar histórico do Oracle no futuro é muito mais custoso do que guardar agora

### Estratégia: lotes semestrais

A query envolve funções Oracle pesadas por linha — um SELECT de 46 meses de uma só vez
pode sobrecarregar ou expirar no Oracle. Estimativa: ~80k linhas/mês × 46 meses ≈ 3,7M
linhas brutas antes da agregação.

Carregar em **lotes semestrais**, um lote por vez:

| Lote | Período                       | Comando dbt                  |
|------|-------------------------------|------------------------------|
| 1    | 2022-08-01 → 2022-12-31       | `dbt run --full-refresh`     |
| 2    | 2023-01-01 → 2023-06-30       | `dbt run`                    |
| 3    | 2023-07-01 → 2023-12-31       | `dbt run`                    |
| 4    | 2024-01-01 → 2024-06-30       | `dbt run`                    |
| 5    | 2024-07-01 → 2024-12-31       | `dbt run`                    |
| 6    | 2025-01-01 → 2025-06-30       | `dbt run`                    |
| 7    | 2025-07-01 → 2025-12-31       | `dbt run`                    |
| 8    | 2026-01-01 → hoje             | `dbt run`                    |

O `--full-refresh` só é usado **no lote 1** — cria a tabela `fato_venda` do zero.
Todos os lotes seguintes usam `dbt run` normal (incremental, upsert).

### Pipeline histórico: parâmetros DATA_INICIO e DATA_FIM

Para a carga histórica, um pipeline Hop separado (`maxv_abcdistribbase_historico.hpl`)
com dois parâmetros no lugar de `WINDOW_DAYS`:

```sql
WHERE V.DTAVDA BETWEEN TO_DATE('${DATA_INICIO}', 'YYYY-MM-DD')
                   AND TO_DATE('${DATA_FIM}',    'YYYY-MM-DD')
AND V.CODGERALOPER IN (800, 810, 820, 828, 202)
```

Após a conclusão de todos os lotes, este pipeline é desativado.
A operação contínua passa para os pipelines hot/cold normais.

### Sequência de execução por lote

```text
1. Ajustar DATA_INICIO e DATA_FIM no pipeline histórico
2. Executar pipeline Hop  →  raw é TRUNCADO e recarregado com o período
3. Executar dbt run       →  dw recebe o lote via upsert
4. Verificar contagem de linhas no dw
5. Avançar para o próximo lote
```

---

## Próximos passos de implementação

1. **Hop**: Criar `maxv_abcdistribbase.hpl` com a query completa + parâmetro `WINDOW_DAYS`
2. **Hop**: Criar `maxv_abcdistribbase_historico.hpl` com parâmetros `DATA_INICIO` e `DATA_FIM`
3. **Hop**: Criar `run_hot.hwf` (workflow diário 4×) e `run_cold.hwf` (workflow madrugada)
4. **dbt**: Criar `stg_maxv_abcdistribbase.sql`
5. **dbt**: Criar `fato_venda.sql` (incremental)
6. **dbt**: Atualizar `_sources.yml`, `_stg_consinco.yml`, `_dw.yml`
7. **Carga histórica**: Executar os 8 lotes (pipeline histórico + dbt run por lote)
8. **Validação**: Comparar totais dw × Power BI atual para mesma data
9. **Agendamento**: Configurar schedules no Hop Server ou Windows Task Scheduler
