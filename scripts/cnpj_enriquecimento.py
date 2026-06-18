"""Enriquecimento de fornecedores via API pública de CNPJ (Minha Receita / BrasilAPI).

Le a lista de CNPJs de gold.dim_fornecedor_info e grava o resultado em
bronze.cnpj_dados_receita. Por padrao roda em modo incremental (so processa
CNPJs ainda nao presentes na tabela); use --full para reprocessar todos.

Variaveis de ambiente esperadas:
  PG_HOSTNAME, PG_PORT, PG_DATABASE
  ENRICHMENT_PG_USERNAME, ENRICHMENT_PG_PASSWORD
"""
import os
import re
import sys
import time

import psycopg2
import requests

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
}
SLEEP_SECONDS = 0.5


def get_connection():
    return psycopg2.connect(
        host=os.environ["PG_HOSTNAME"],
        port=os.environ.get("PG_PORT", "5432"),
        dbname=os.environ["PG_DATABASE"],
        user=os.environ["ENRICHMENT_PG_USERNAME"],
        password=os.environ["ENRICHMENT_PG_PASSWORD"],
    )


def cnpjs_pendentes(conn, full: bool):
    with conn.cursor() as cur:
        if full:
            cur.execute(
                """
                SELECT DISTINCT cnpj_cpf
                FROM gold.dim_fornecedor_info
                WHERE pessoa_tipo = 'JURÍDICA' AND LENGTH(cnpj_cpf) = 14
                """
            )
        else:
            cur.execute(
                """
                SELECT DISTINCT d.cnpj_cpf
                FROM gold.dim_fornecedor_info d
                LEFT JOIN bronze.cnpj_dados_receita r ON r.cnpj = d.cnpj_cpf
                WHERE d.pessoa_tipo = 'JURÍDICA'
                  AND LENGTH(d.cnpj_cpf) = 14
                  AND r.cnpj IS NULL
                """
            )
        return [row[0] for row in cur.fetchall()]


def consultar_cnpj(cnpj: str):
    """Retorna um dict com os campos parseados, ou None se nao encontrado/erro."""
    for url, fonte in (
        (f"https://minhareceita.org/{cnpj}", "minha_receita"),
        (f"https://brasilapi.com.br/api/cnpj/v1/{cnpj}", "brasilapi"),
    ):
        try:
            response = requests.get(url, headers=HEADERS, timeout=8)
        except requests.RequestException:
            continue
        if response.status_code != 200:
            continue
        dados = response.json()
        situacao = dados.get("situacao_cadastral")
        cnae = dados.get("cnae_fiscal")
        return {
            "cnpj": cnpj,
            "situacao_cadastral": str(situacao) if situacao is not None else None,
            "descricao_situacao_cadastral": dados.get("descricao_situacao_cadastral"),
            "opcao_pelo_simples": dados.get("opcao_pelo_simples"),
            "data_opcao_pelo_simples": dados.get("data_opcao_pelo_simples"),
            "opcao_pelo_mei": dados.get("opcao_pelo_mei"),
            "data_opcao_pelo_mei": dados.get("data_opcao_pelo_mei"),
            "porte": dados.get("porte"),
            "descricao_porte": dados.get("descricao_porte"),
            "capital_social": dados.get("capital_social"),
            "data_inicio_atividade": dados.get("data_inicio_atividade"),
            "cnae_fiscal": str(cnae) if cnae is not None else None,
            "cnae_fiscal_descricao": dados.get("cnae_fiscal_descricao"),
            "fonte_api": fonte,
        }
    return None


UPSERT_SQL = """
INSERT INTO bronze.cnpj_dados_receita (
    cnpj, situacao_cadastral, descricao_situacao_cadastral,
    opcao_pelo_simples, data_opcao_pelo_simples,
    opcao_pelo_mei, data_opcao_pelo_mei,
    porte, descricao_porte, capital_social, data_inicio_atividade,
    cnae_fiscal, cnae_fiscal_descricao, fonte_api, _loaded_at
) VALUES (
    %(cnpj)s, %(situacao_cadastral)s, %(descricao_situacao_cadastral)s,
    %(opcao_pelo_simples)s, %(data_opcao_pelo_simples)s,
    %(opcao_pelo_mei)s, %(data_opcao_pelo_mei)s,
    %(porte)s, %(descricao_porte)s, %(capital_social)s, %(data_inicio_atividade)s,
    %(cnae_fiscal)s, %(cnae_fiscal_descricao)s, %(fonte_api)s, now()
)
ON CONFLICT (cnpj) DO UPDATE SET
    situacao_cadastral = EXCLUDED.situacao_cadastral,
    descricao_situacao_cadastral = EXCLUDED.descricao_situacao_cadastral,
    opcao_pelo_simples = EXCLUDED.opcao_pelo_simples,
    data_opcao_pelo_simples = EXCLUDED.data_opcao_pelo_simples,
    opcao_pelo_mei = EXCLUDED.opcao_pelo_mei,
    data_opcao_pelo_mei = EXCLUDED.data_opcao_pelo_mei,
    porte = EXCLUDED.porte,
    descricao_porte = EXCLUDED.descricao_porte,
    capital_social = EXCLUDED.capital_social,
    data_inicio_atividade = EXCLUDED.data_inicio_atividade,
    cnae_fiscal = EXCLUDED.cnae_fiscal,
    cnae_fiscal_descricao = EXCLUDED.cnae_fiscal_descricao,
    fonte_api = EXCLUDED.fonte_api,
    _loaded_at = now()
"""


def main():
    full = "--full" in sys.argv
    conn = get_connection()
    conn.autocommit = True

    cnpjs = cnpjs_pendentes(conn, full)
    print(f"Modo: {'FULL' if full else 'INCREMENTAL'} — {len(cnpjs)} CNPJs a processar.")

    sucesso, falha = 0, 0
    for i, cnpj in enumerate(cnpjs, start=1):
        dados = consultar_cnpj(cnpj)
        if dados is None:
            print(f"[{i}/{len(cnpjs)}] {cnpj}: nao encontrado/erro nas APIs.")
            falha += 1
        else:
            try:
                with conn.cursor() as cur:
                    cur.execute(UPSERT_SQL, dados)
                print(f"[{i}/{len(cnpjs)}] {cnpj}: {dados['descricao_situacao_cadastral']} "
                      f"(simples={dados['opcao_pelo_simples']}, fonte={dados['fonte_api']})")
                sucesso += 1
            except psycopg2.Error as e:
                print(f"[{i}/{len(cnpjs)}] {cnpj}: ERRO ao gravar — {e}")
                falha += 1
        time.sleep(SLEEP_SECONDS)

    conn.close()
    print(f"\nConcluido: {sucesso} ok, {falha} falha(s) de {len(cnpjs)} processado(s).")


if __name__ == "__main__":
    main()
