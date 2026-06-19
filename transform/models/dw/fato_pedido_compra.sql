{{ config(
    materialized='incremental',
    unique_key=['pedido_id', 'empresa_id', 'produto_id'],
    on_schema_change='append_new_columns',
    incremental_strategy='delete+insert',
    indexes=[
      {'columns': ['pedido_id', 'empresa_id', 'produto_id'], 'unique': True},
      {'columns': ['dta_emissao'], 'type': 'btree'},
      {'columns': ['empresa_id'], 'type': 'btree'},
      {'columns': ['produto_id'], 'type': 'btree'},
      {'columns': ['fornecedor_id'], 'type': 'btree'}
    ]
) }}

WITH header AS (
    SELECT * FROM {{ ref('stg_msu_pedidosuprim') }}
    {% if is_incremental() %}
    WHERE dta_emissao >= (
        SELECT MIN(dtaemissao::DATE) FROM {{ source('consinco', 'msu_pedidosuprim') }}
    )
    {% endif %}
),

item AS (
    SELECT * FROM {{ ref('stg_msu_psitemreceber') }}
)

SELECT
    h.pedido_id,
    h.empresa_id,
    i.item_seq,
    i.produto_id,
    h.central_loja,
    h.fornecedor_id,
    h.comprador_id,
    h.transportador_id,
    h.tip_pedido_suprim,
    h.situacao_ped,
    i.status_item,
    h.dta_emissao,
    h.dta_aprovacao,
    h.dta_recebto,
    i.dta_recebto_item,
    h.dta_limite_recebto,
    CASE
        WHEN i.dta_recebto_item IS NOT NULL THEN i.dta_recebto_item - h.dta_emissao
        ELSE NULL
    END                                                          AS dias_lead_time_emissao_recebimento,
    h.dias_prorrogacao,
    i.qtd_solicitada,
    i.qtd_solicitada_original,
    i.qtd_aprovada,
    i.qtd_tot_recebida,
    i.qtd_tot_cancelada,
    i.qtd_tot_transito,
    i.vlr_unitario,
    i.vlr_emb_item,
    COALESCE(i.motivo_pendencia, h.motivo_pendencia)            AS motivo_pendencia,
    h.nro_ped_suprim_orig,
    h.empresa_orig_id,
    h.tipo_ped_venda,
    h.ind_transf_emp_sec,
    h.observacao,
    i.observacao_item,
    i.carregado_em
FROM item i
INNER JOIN header h ON h.pedido_id = i.pedido_id AND h.empresa_id = i.empresa_id
