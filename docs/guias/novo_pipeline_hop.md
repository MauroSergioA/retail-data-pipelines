# Como criar um novo pipeline Hop (extração Oracle → PostgreSQL)

## Padrão do projeto

Todo pipeline de extração segue o mesmo fluxo de 3 transforms:

```
src_<tabela>         →    sys_loaded_at    →    raw_<tabela>
(TableInput Oracle)       (SystemInfo)          (TableOutput PG)
```

O `sys_loaded_at` injeta `_loaded_at` com o timestamp de início da execução —
o mesmo valor em todas as linhas do run.

## Passo a passo

### 1. Criar o arquivo `.hpl`

Salvar em `extract/consinco/<nome_da_tabela_oracle_em_minusculas>.hpl`.

Exemplo: tabela `MAP_PRODUTO` → arquivo `extract/consinco/map_produto.hpl`.

### 2. Adicionar o transform de origem (TableInput Oracle)

- Tipo: **Table Input**
- Nome: `src_<tabela>` (ex.: `src_map_produto`)
- Conexão: `oracle-consinco`
- SQL:

```sql
SELECT
    COLUNA1,
    COLUNA2,
    ...
FROM CONSINCO.<TABELA>
```

Regras:
- Usar apenas nomes de coluna Oracle em maiúsculas no SELECT
- Não usar `--` para comentários — pode interferir na detecção de campos pelo JDBC
- Não colocar `;` no final
- Se usar parâmetros Hop (`${PARAM}`): marcar **"Replace variables in script"**

### 3. Adicionar o transform de timestamp (SystemInfo)

- Tipo: **Get System Info**
- Nome: `sys_loaded_at`
- Campo: `_loaded_at` → tipo **system date (fixed)**

"System date (fixed)" captura o timestamp uma única vez no início do pipeline —
garante que todas as linhas do run tenham o mesmo `_loaded_at`.

### 4. Adicionar o transform de destino (TableOutput PostgreSQL)

- Tipo: **Table Output**
- Nome: `raw_<tabela>` (ex.: `raw_map_produto`)
- Conexão: `postgres-dw`
- Schema: `raw`
- Tabela: `<nome_da_tabela_em_minusculas>` (ex.: `map_produto`)
- **Truncate table**: ✅ Sim (para cargas completas diárias)
- **Commit size**: 50000

### 5. Conectar os transforms

```
src_<tabela>  →  sys_loaded_at  →  raw_<tabela>
```

### 6. Testar o pipeline

Executar no Hop e verificar:
- Sem erros em vermelho no log
- Número de linhas no `raw_<tabela>` bate com o esperado
- Coluna `_loaded_at` preenchida

Consulta de verificação:

```sql
SELECT COUNT(*), MAX(_loaded_at) FROM raw.<tabela>;
```

### 7. Criar o modelo dbt staging

Arquivo: `transform/models/staging/consinco/stg_<tabela>.sql`

```sql
WITH source AS (
    SELECT * FROM {{ source('consinco', '<tabela>') }}
)

SELECT
    coluna_oracle::TIPO    AS nome_snake_case,
    ...
    _loaded_at::TIMESTAMP  AS loaded_at
FROM source
```

Convenções de nomes de colunas: ver [docs/arquitetura/convencoes.md](../arquitetura/convencoes.md).

### 8. Declarar o source no `_sources.yml`

Arquivo: `transform/models/staging/consinco/_sources.yml`

```yaml
- name: <tabela>
  description: "Descrição da tabela"
  columns:
    - name: _loaded_at
      description: "Timestamp de início da extração Hop"
```

### 9. Declarar o modelo no `_stg_consinco.yml`

Arquivo: `transform/models/staging/consinco/_stg_consinco.yml`

```yaml
- name: stg_<tabela>
  description: "Descrição do modelo staging"
  columns:
    - name: <chave_primaria>
      data_tests:
        - not_null
        - unique
    - name: loaded_at
      data_tests:
        - not_null
```

### 10. Documentar

Criar `docs/fontes/consinco/<tabela>.md` seguindo o modelo de
[max_empresa.md](../fontes/consinco/max_empresa.md).

Adicionar a tabela na lista de `docs/fontes/consinco.md`.

## Pipelines com janela incremental (fatos)

Para fatos com `WINDOW_DAYS` (como `maxv_abcdistribbase`):

- Declarar o parâmetro no pipeline: **Pipeline > Parameters > Add**
  - Nome: `WINDOW_DAYS`, Valor padrão: `0`
- Na SQL do TableInput, adicionar no WHERE:
  ```sql
  AND DATA_COLUNA >= TRUNC(SYSDATE) - ${WINDOW_DAYS}
  ```
- Marcar **"Replace variables in script"** no TableInput
- Configurar o TableOutput **sem** Truncate (a janela controla o volume)

Criar dois workflows para agendamento:
- `run_hot.hwf` — `WINDOW_DAYS=0`, executa 4× por dia
- `run_cold.hwf` — `WINDOW_DAYS=5`, executa 1× na madrugada
