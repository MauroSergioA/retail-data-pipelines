{#
  Escreve de volta no NocoDB (nocodb.meta_ajustes_loja, via postgres_fdw) o
  valor calculado do rateio por loja - assim a diretoria ve, na MESMA tabela
  onde digita o ajuste manual, quanto cada loja receberia sem ajuste nenhum.
  As colunas "Final" (meta_padrao_final/meta_desafio_final) sao Formula
  nativa do NocoDB (sem_ajuste + ajuste) - atualizam na hora, sem depender
  desse macro.

  So toca nas colunas calculadas (participacao_loja_calculada,
  meta_padrao_sem_ajuste, meta_desafio_sem_ajuste) - nunca escreve em
  ajuste_padrao_valor/ajuste_desafio_valor, que sao input manual da
  diretoria. postgres_fdw nao suporta INSERT ... ON CONFLICT contra foreign
  table, por isso UPDATE e INSERT (com NOT EXISTS) sao feitos em dois passos
  separados, nao um upsert so.

  Chamado como post-hook do mart_meta_comercial - roda automaticamente toda
  vez que o rateio recalcula.
#}
{% macro sync_meta_ajustes_calculado() %}

  {% set update_sql %}
    WITH loja_totais AS (
        SELECT
            mc.mes,
            mc.empresa_id,
            SUM(mc.meta_padrao_valor) AS meta_loja_padrao_com_ajuste,
            SUM(mc.meta_desafio_valor) AS meta_loja_desafio_com_ajuste
        FROM {{ this }} mc
        GROUP BY 1, 2
    ),
    calculado AS (
        SELECT
            lt.mes,
            lt.empresa_id,
            lt.meta_loja_padrao_com_ajuste - COALESCE(aj.ajuste_padrao_valor, 0) AS meta_padrao_sem_ajuste,
            lt.meta_loja_desafio_com_ajuste - COALESCE(aj.ajuste_desafio_valor, 0) AS meta_desafio_sem_ajuste,
            (lt.meta_loja_padrao_com_ajuste - COALESCE(aj.ajuste_padrao_valor, 0)) / mp.meta_grupo_padrao_valor AS participacao_loja_calculada
        FROM loja_totais lt
        INNER JOIN {{ ref('stg_nocodb_meta_parametros') }} mp ON mp.mes = lt.mes
        LEFT JOIN {{ source('nocodb', 'meta_ajustes_loja') }} aj
            ON aj.mes = lt.mes AND aj.empresa_id = lt.empresa_id
    )
    UPDATE {{ source('nocodb', 'meta_ajustes_loja') }} AS destino
    SET
        participacao_loja_calculada = c.participacao_loja_calculada,
        meta_padrao_sem_ajuste = c.meta_padrao_sem_ajuste,
        meta_desafio_sem_ajuste = c.meta_desafio_sem_ajuste
    FROM calculado c
    WHERE destino.mes = c.mes AND destino.empresa_id = c.empresa_id
  {% endset %}

  {% do run_query(update_sql) %}

  {% set insert_sql %}
    WITH loja_totais AS (
        SELECT
            mc.mes,
            mc.empresa_id,
            SUM(mc.meta_padrao_valor) AS meta_padrao_sem_ajuste,
            SUM(mc.meta_desafio_valor) AS meta_desafio_sem_ajuste
        FROM {{ this }} mc
        GROUP BY 1, 2
    ),
    novos AS (
        SELECT
            lt.mes,
            lt.empresa_id,
            lt.meta_padrao_sem_ajuste,
            lt.meta_desafio_sem_ajuste,
            lt.meta_padrao_sem_ajuste / mp.meta_grupo_padrao_valor AS participacao_loja_calculada
        FROM loja_totais lt
        INNER JOIN {{ ref('stg_nocodb_meta_parametros') }} mp ON mp.mes = lt.mes
        WHERE NOT EXISTS (
            SELECT 1 FROM {{ source('nocodb', 'meta_ajustes_loja') }} aj
            WHERE aj.mes = lt.mes AND aj.empresa_id = lt.empresa_id
        )
    )
    -- "id" tem default por sequence no banco nocodb (nao acessivel via FDW
    -- entre bancos) - gerado aqui a partir do MAX atual + ROW_NUMBER. Seguro
    -- porque esse sync roda sempre sequencial (post-hook de um unico model),
    -- nunca concorrente.
    INSERT INTO {{ source('nocodb', 'meta_ajustes_loja') }}
        (id, mes, empresa_id, ajuste_padrao_valor, ajuste_desafio_valor,
         participacao_loja_calculada, meta_padrao_sem_ajuste, meta_desafio_sem_ajuste)
    SELECT
        (SELECT COALESCE(MAX(id), 0) FROM {{ source('nocodb', 'meta_ajustes_loja') }}) + ROW_NUMBER() OVER (),
        mes, empresa_id, 0, 0, participacao_loja_calculada, meta_padrao_sem_ajuste, meta_desafio_sem_ajuste
    FROM novos
  {% endset %}

  {% do run_query(insert_sql) %}

{% endmacro %}
