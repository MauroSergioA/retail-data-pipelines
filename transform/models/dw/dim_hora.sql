{{ config(materialized='table') }}

SELECT
    hora                                            AS hora_num,

    LPAD(hora::TEXT, 2, '0') || 'h'                AS hora_texto,

    CASE
        WHEN hora < 6  THEN 'MADRUGADA'
        WHEN hora < 12 THEN 'MANHÃ'
        WHEN hora < 18 THEN 'TARDE'
        ELSE                'NOITE'
    END                                             AS periodo,

    CASE WHEN hora < 12 THEN 'AM' ELSE 'PM' END    AS am_pm

FROM generate_series(0, 23) hora
ORDER BY hora
