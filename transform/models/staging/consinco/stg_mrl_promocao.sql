WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_promocao') }}
)

SELECT
    -- chave composta
    seqpromocao::INTEGER                        AS promocao_id,
    nroempresa::INTEGER                         AS empresa_id,
    nrosegmento::INTEGER                        AS segmento_id,
    nrodivisao::INTEGER                         AS divisao_id,
    UPPER(centralloja)::TEXT                    AS central_loja,
    -- descrição
    UPPER(promocao)::TEXT                       AS promocao,
    UPPER(tipopromoc)::TEXT                     AS tipo_promoc,
    -- vigência
    dtainicio::DATE                             AS dta_inicio,
    dtafim::DATE                                AS dta_fim,
    -- indicadores
    CASE UPPER(indprevalecepreco)
        WHEN 'S' THEN 'SIM'
        WHEN 'N' THEN 'NÃO'
        ELSE 'NÃO INFORMADO'
    END                                         AS ind_prevalece_preco,
    CASE UPPER(indsegmentoprinc)
        WHEN 'S' THEN 'SIM'
        WHEN 'N' THEN 'NÃO'
        ELSE 'NÃO INFORMADO'
    END                                         AS ind_segmento_princ,
    seqencarte::INTEGER                         AS encarte_id,
    -- auditoria
    dtageracaopromoc::DATE                      AS dta_geracao,
    dtahorainclusao::TIMESTAMP                  AS dta_hora_inclusao,
    dtahoraalteracao::TIMESTAMP                 AS dta_hora_alteracao,
    UPPER(usuinclusao)::TEXT                    AS usuario_inclusao,
    UPPER(usualteracao)::TEXT                   AS usuario_alteracao,
    _loaded_at::TIMESTAMP                       AS carregado_em
FROM source
