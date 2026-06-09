WITH fornecedor_divisao AS (
    SELECT * FROM {{ source('consinco', 'maf_fornecdivisao') }}
)

SELECT
  nrodivisao::INTEGER             AS divisao_id,
  seqfornecedor::INTEGER          AS fornecedor_id,
  pzomedvisitarep::NUMERIC        AS prazo_medio_visita_representante,
  pzomedentrega::NUMERIC          AS prazo_med_entrega,
  pzomedatraso::NUMERIC           AS prazo_med_atraso,
  pzopagamento::TEXT              AS prazo_pagamento,
  nrocondpagdev::INTEGER          AS condicao_pagamento_id,
  nroformapagtodev::INTEGER       AS forma_pagamento_id,
  CASE UPPER(statusgeral)
    WHEN 'A' THEN 'ATIVO'
    WHEN 'I' THEN 'INATIVO'
    ELSE 'OUTRO'
  END                             AS status_fornecedor,
  _loaded_at::TIMESTAMP           AS carregado_em
FROM fornecedor_divisao

