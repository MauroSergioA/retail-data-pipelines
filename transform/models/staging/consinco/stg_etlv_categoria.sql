WITH source AS (
    SELECT * FROM {{ source('consinco', 'etlv_categoria') }}
),

deduplicado AS (
    SELECT
        nrodivisao::INTEGER                                                         AS divisao_id,
        seqfamilia::INTEGER                                                         AS familia_id,
        skcategoria::INTEGER                                                        AS sk_categoria,
        UPPER(categoriacompleta)::TEXT                                              AS categoria_completa,
        LPAD(skcategoria::TEXT, 4, '0') || ' - ' || UPPER(categoriacompleta)        AS categoria_completa_id_nome,
        seqcategorian1::INTEGER                                                     AS categoria_id,
        UPPER(categorian1)::TEXT                                                    AS categoria,
        LPAD(seqcategorian1::TEXT, 4, '0') || ' - ' || UPPER(categorian1)           AS categoria_id_nome,
        seqcategorian2::INTEGER                                                     AS subcategoria_id,
        UPPER(categorian2)::TEXT                                                    AS subcategoria,
        CASE
            WHEN seqcategorian2 IS NULL THEN '0000 - NÃO DEFINIDA'
            ELSE LPAD(seqcategorian2::TEXT, 4, '0') || ' - ' || UPPER(categorian2)
        END                                                                         AS subcategoria_id_nome,
        CASE
            WHEN seqcategorian3 IS NULL THEN 0
            ELSE seqcategorian3::INTEGER
        END                                                                         AS grupo_id,
        CASE
            WHEN seqcategorian3 IS NULL THEN 'NÃO DEFINIDO'
            ELSE UPPER(categorian3)
        END                                                                         AS grupo,
        CASE
            WHEN seqcategorian3 IS NULL THEN '0000 - NÃO DEFINIDO'
            ELSE LPAD(seqcategorian3::TEXT, 4, '0') || ' - ' || UPPER(categorian3)
        END                                                                         AS grupo_id_nome,
        CASE
            WHEN seqcategorian1 IN (1978, 2690, 2685, 1980, 1982) THEN 'PERECÍVEL'
            ELSE 'NÃO PERECÍVEL'
        END                                                                         AS perecivel,
        _loaded_at::TIMESTAMP                                                       AS carregado_em,
        ROW_NUMBER() OVER (
            PARTITION BY seqfamilia
            ORDER BY
                CASE WHEN nrodivisao = 1 THEN 0 ELSE 1 END,
                nrodivisao
        )                                                                           AS rn
    FROM source
)

SELECT
    divisao_id,
    familia_id,
    sk_categoria,
    categoria_completa,
    categoria_completa_id_nome,
    categoria_id,
    categoria,
    categoria_id_nome,
    subcategoria_id,
    subcategoria,
    subcategoria_id_nome,
    grupo_id,
    grupo,
    grupo_id_nome,
    perecivel,
    carregado_em
FROM deduplicado
WHERE rn = 1
