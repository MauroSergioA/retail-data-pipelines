WITH fornecedor_familia AS (
    SELECT distinct ON (fornecedor_id)
        fornecedor_id,
        fornecedor_principal,
        indeniza_avaria,
        carregado_em
    FROM {{ ref('stg_map_famfornec') }}
    ORDER BY fornecedor_id
),

fornecedor_divisao AS (
    SELECT *
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY fornecedor_id
                ORDER BY
                    CASE WHEN divisao_id = 1 THEN 0 ELSE 1 END,
                    carregado_em DESC
            ) AS rn
        FROM {{ ref('stg_maf_fornecdivisao') }}
    ) t
    WHERE rn = 1
),

pessoa AS (
    SELECT * FROM {{ ref('stg_ge_pessoa') }}
)


SELECT
    ff.fornecedor_id,
    p.nome_razao,
    p.nome_razao_id_nome,
    p.nome_fantasia,
    p.status,
    p.pessoa_tipo,
    p.logradouro,
    p.numero,
    p.bairro,
    p.cidade,
    p.cep,
    p.uf,
    p.pais,
    p.endereco,
    p.cnpj_cpf,
    p.inscricao_rg,
    p.email,
    p.contribuinte_icms,
    p.produtor_rural,
    p.contribuinte_ipi,
    p.cnae,
    ff.fornecedor_principal,
    ff.indeniza_avaria,
    fd.prazo_medio_visita_representante,
    fd.prazo_med_entrega,
    fd.prazo_med_atraso,
    fd.prazo_pagamento,
    fd.condicao_pagamento_id,
    fd.forma_pagamento_id,
    fd.divisao_id,
    ff.carregado_em
FROM fornecedor_familia                 ff
LEFT JOIN fornecedor_divisao            fd ON ff.fornecedor_id = fd.fornecedor_id
LEFT JOIN pessoa                        p  ON ff.fornecedor_id = p.pessoa_id




