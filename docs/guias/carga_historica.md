# Carga histórica — fato_venda

## Visão geral

A carga histórica popula `dw.fato_venda` com dados desde 01/08/2022.
É um processo manual, executado uma vez, em lotes trimestrais.

O pipeline `maxv_abcdistribbase_historico.hpl` extrai um intervalo fechado
(`DATA_INICIO` → `DATA_FIM`) diretamente para o raw, e o dbt incremental acumula o resultado.

## Por que lotes trimestrais?

A query Oracle com funções `FC5` demora ~90 segundos para um dia de dados (~67k linhas).
Um trimestre (~6M linhas) leva aproximadamente 7 minutos — viável e sem risco de timeout.
Semestres ou anos inteiros podem ultrapassar limites de JDBC/memória.

## Lotes planejados

| # | DATA_INICIO | DATA_FIM | Status |
|---|-------------|----------|--------|
| 1 | 2022-08-01 | 2022-10-31 | ✅ concluído (2026-05-28) |
| 2 | 2022-11-01 | 2023-01-31 | ✅ concluído (2026-05-29) |
| 3 | 2023-02-01 | 2023-04-30 | ✅ concluído (2026-06-03) |
| 4 | 2023-05-01 | 2023-07-31 | ✅ concluído (2026-06-03) |
| 5 | 2023-08-01 | 2023-10-31 | ✅ concluído (2026-06-03) |
| 6 | 2023-11-01 | 2024-01-31 | ✅ concluído (2026-06-03) |
| 7 | 2024-02-01 | 2024-04-30 | ✅ concluído (2026-06-03) |
| 8 | 2024-05-01 | 2024-07-31 | ✅ concluído (2026-06-03) |
| 9 | 2024-08-01 | 2024-10-31 | ✅ concluído (2026-06-03) |
| 10 | 2024-11-01 | 2025-01-31 | ✅ concluído (2026-06-03) |
| 11 | 2025-02-01 | 2025-04-30 | ✅ concluído (2026-06-03) |
| 12 | 2025-05-01 | 2025-07-31 | ✅ concluído (2026-06-03) |
| 13 | 2025-08-01 | 2025-10-31 | pendente |
| 14 | 2025-11-01 | 2026-01-31 | pendente |
| 15 | 2026-02-01 | 2026-04-30 | pendente |
| 16 | 2026-05-01 | hoje | pendente |

## Passo a passo por lote

### 1. Abrir o pipeline histórico no Hop

Arquivo: `extract/consinco/maxv_abcdistribbase_historico.hpl`

### 2. Configurar os parâmetros

No painel de parâmetros do pipeline, definir:

| Parâmetro     | Exemplo (lote 2) |
|---------------|------------------|
| `DATA_INICIO` | `2022-11-01`     |
| `DATA_FIM`    | `2023-01-31`     |

### 3. Executar o pipeline no Hop

Clicar em **Run**. Aguardar a conclusão (~7 min por trimestre).

Verificar no log:

- Sem erros em vermelho
- Número de linhas no transform `raw_maxv_abcdistribbase` > 0

### 4. Rodar o dbt incremental

```powershell
$env:PATH = "C:\venv\dbt\Scripts;$env:PATH"
cd C:\Projetos\retail-data-pipelines\transform
dbt run --select fato_venda
```

O dbt detecta automaticamente a janela do raw e processa apenas o lote carregado.

### 5. Verificar o resultado

```sql
SELECT
    MIN(dta_venda) AS primeira_data,
    MAX(dta_venda) AS ultima_data,
    COUNT(*) AS linhas,
    SUM(vlr_venda_liq) AS faturamento
FROM dw.fato_venda
WHERE dta_venda BETWEEN '2022-11-01' AND '2023-01-31';
```

### 6. Atualizar a tabela de lotes acima

Marcar o lote como ✅ concluído e anotar a data.

## Importante

- O raw (`raw.maxv_abcdistribbase`) é um buffer: o próximo lote sobrescreve o anterior.
  **Não rodar dois lotes em paralelo** — o segundo TRUNCATE apagará o primeiro antes do dbt processar.
- O dw **acumula** histórico: rodar o dbt em sequência é seguro, ele nunca apaga dados fora da janela.
- A produção (hot/cold automático) pode continuar rodando normalmente durante a carga histórica —
  os lotes históricos e os dados de hoje nunca se sobrepõem.
