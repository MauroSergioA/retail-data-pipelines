WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_local') }}
)

SELECT
    nroempresa::INTEGER                AS empresa_id,
    seqlocal::INTEGER                  AS local_id,
    UPPER(local)::TEXT                 AS descricao_local,
    UPPER(tiplocal)::TEXT              AS tipo_local,
    UPPER(status)::TEXT                AS status_local,
    _loaded_at::TIMESTAMP              AS carregado_em
FROM source
