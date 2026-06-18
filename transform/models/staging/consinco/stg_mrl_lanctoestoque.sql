WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_lanctoestoque') }}
)

SELECT
    seqmovtoestq::BIGINT               AS movimento_id,
    nroempresa::INTEGER                AS empresa_id,
    dtaentradasaida::DATE              AS dta_movimento,
    dtahorlancto::TIMESTAMP            AS dta_hor_lancto,
    seqproduto::INTEGER                AS produto_id,
    seqprodutobase::INTEGER            AS produto_base_id,
    "LOCAL"::INTEGER                   AS local_id,
    codgeraloper::INTEGER              AS cod_geral_oper,
    UPPER(tipusocgo)::TEXT             AS tip_uso_cgo,
    UPPER(tiplancto)::TEXT             AS tip_lancto,
    CASE
        WHEN UPPER(tiplancto) = 'E' THEN 1
        WHEN UPPER(tiplancto) = 'S' THEN -1
        ELSE 0
    END * qtdlancto::NUMERIC           AS qtd_lancto,
    CASE
        WHEN UPPER(tiplancto) = 'E' THEN 1
        WHEN UPPER(tiplancto) = 'S' THEN -1
        ELSE 0
    END * valorvlrnf::NUMERIC          AS vlr_nf_lancto,
    nrodocumento::TEXT                 AS nro_documento,
    UPPER(motivomovto)::TEXT           AS motivo_movto,
    seqloteestoque::INTEGER            AS lote_estoque_id,
    historico::TEXT                    AS historico,
    _loaded_at::TIMESTAMP              AS carregado_em
FROM source
