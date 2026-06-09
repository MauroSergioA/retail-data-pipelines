WITH source AS (
    SELECT * FROM {{ source('consinco', 'ge_pessoa') }}
)

SELECT
    seqpessoa::INTEGER                                                      AS pessoa_id,
    UPPER(nomerazao)::TEXT                                                  AS nome_razao,
    LPAD(seqpessoa::TEXT, 5, '0') || ' - ' || UPPER(nomerazao)::TEXT        AS nome_razao_id_nome,
    UPPER(fantasia)::TEXT                                                   AS nome_fantasia,
    CASE UPPER(status)
        WHEN 'A' THEN 'ATIVO'
        ELSE 'INATIVO'
    END                                                                     AS status,
    CASE UPPER(fisicajuridica)
        WHEN 'F' THEN 'FÍSICA'
        ELSE 'JURÍDICA'
    END                                                                     AS pessoa_tipo,
    UPPER(logradouro)::TEXT                                                 AS logradouro,
    UPPER(nrologradouro)::TEXT                                              AS numero,
    UPPER(bairro)::TEXT                                                     AS bairro,
    UPPER(cidade)::TEXT                                                     AS cidade,
    UPPER(cep)::TEXT                                                        AS cep,
    UPPER(uf)::TEXT                                                         AS uf,
    UPPER(pais)::TEXT                                                       AS pais,
    CONCAT_WS(
        ' - ',
        UPPER(logradouro)::TEXT,
        COALESCE(UPPER(nrologradouro)::TEXT, 'S/N'),
        UPPER(bairro)::TEXT,
        UPPER(cep)::TEXT,
        UPPER(cidade)::TEXT,
        UPPER(uf)::TEXT,
        UPPER(pais)::TEXT
    ) AS endereco,
    CASE UPPER(fisicajuridica)
        WHEN 'F' THEN LPAD(nrocgccpf::TEXT, 9, '0')
        WHEN 'J' THEN LPAD(nrocgccpf::TEXT, 12, '0')
    END 
    || CASE
        WHEN digcgccpf IS NOT NULL THEN LPAD(digcgccpf::TEXT, 2, '0')
    END                                                                     AS cnpj_cpf,
    UPPER(inscricaorg)::TEXT                                                AS inscricao_rg,
    UPPER(email)::TEXT                                                      AS email,
    CASE UPPER(indcontribicms)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                     AS contribuinte_icms,
    CASE UPPER(indprodrural)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                     AS produtor_rural,
    CASE UPPER(indcontribipi)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                     AS contribuinte_ipi,
    UPPER(cnae::TEXT)                                                       AS cnae,
    dtainclusao::DATE                                                       AS data_inclusao,
    _loaded_at::TIMESTAMP                                                   AS carregado_em
FROM source
