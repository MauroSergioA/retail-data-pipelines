WITH empresa AS (
    SELECT 
        *
    FROM {{ ref('stg_max_empresa') }}
),

pdv_ativo_por_loja AS (
    SELECT
        empresa_id,
        COUNT(*) AS total_pdv_ativo
    FROM {{ ref('stg_vw_pdv') }}
    WHERE pdv_ativo = 'SIM'
    GROUP BY empresa_id
),

lojas_por_cidade AS (
    SELECT
        cidade,
        COUNT(*) AS total_lojas_cidade
    FROM empresa
    WHERE empresa_id != 1
    GROUP BY cidade
),

ranking_por_cidade AS (
    SELECT
        e.*,
        ROW_NUMBER() OVER (PARTITION BY e.cidade ORDER BY e.empresa_id) AS rank_na_cidade
    FROM empresa e
),

segmento AS (
    SELECT 
        *   
    FROM {{ ref('stg_mad_segmento') }}
)

SELECT
    r.divisao_id                                                                            AS divisao_id,
    r.empresa_id                                                                            AS empresa_id,
    CASE
        WHEN r.empresa_id = 1
            THEN '001 - MATRIZ'
        WHEN c.total_lojas_cidade > 1
            THEN LPAD(r.empresa_id::TEXT, 3, '0') || ' - ' || r.cidade || ' L' || r.rank_na_cidade
        ELSE
            LPAD(r.empresa_id::TEXT, 3, '0') || ' - ' || r.cidade
    END                                                                                     AS loja,
    r.razao_social                                                                          AS razao_social,
    r.pessoa_id_razao,
    r.cnpj,
    r.inscricao_estadual,
    r.logradouro,
    r.bairro,
    r.cep,
    r.cidade,
    r.uf,
    r.endereco,
    r.metro_quadrado,
    r.pessoa_id,
    r.segmento_principal,
    s.segmento_id_nome,
    r.aberto_sabado,
    r.aberto_domingo,
    r.meta_margem_lucro,
    r.meta_dia_estoque,
    r.status_empresa,
    r.dta_fechamento_fiscal,
    r.inicio_estoque,
    r.nsu_nf,
    p.total_pdv_ativo,
    r.cgo_baixa_saida_pdv,
    r.cgo_transf_loc_ori,
    r.cgo_transf_loc_dest,
    r.cgo_baixa_producao,
    r.cgo_entr_producao,
    r.cgo_baixa_inventario,
    r.cgo_entr_inventario,
    r.cgo_emiss_nf_venda,
    r.cgo_entr_transf,
    r.cgo_dev_fornec,
    r.cgo_entr_transf_prod,
    r.cgo_sai_transf_prod,
    r.cgo_baixa_perda,
    r.cgo_ajuste_custo,
    r.cgo_ajuste_custo_redu,
    r.carregado_em 
FROM ranking_por_cidade                   r
LEFT JOIN lojas_por_cidade                c ON r.cidade = c.cidade
LEFT JOIN pdv_ativo_por_loja              p ON r.empresa_id = p.empresa_id
LEFT JOIN segmento                        s ON r.segmento_principal = s.segmento_id
ORDER BY r.empresa_id



