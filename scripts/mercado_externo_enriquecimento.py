"""Enriquecimento de indicadores de mercado externo (IPCA via BCB, PMC via IBGE).

Alimenta bronze.indicadores_mercado_externo, usado pra dar contexto de
inflacao e crescimento do setor na definicao da meta comercial (ver
docs/negocio/redesign_dashboards.md, secao "Apoio a Definicao de Meta do Grupo").

Fontes:
  - BCB SGS (series 433 = IPCA geral, 1635 = IPCA alimentacao e bebidas)
  - IBGE Agregados (tabela 8882 = PMC por atividades, categoria 103154 =
    Hipermercados e supermercados, indice de volume de vendas)

Variaveis de ambiente esperadas:
  PG_HOSTNAME, PG_PORT, PG_DATABASE
  ENRICHMENT_PG_USERNAME, ENRICHMENT_PG_PASSWORD
"""
import os
import sys
from datetime import date, timedelta

import psycopg2
import requests

HEADERS = {"User-Agent": "retail-data-pipelines/1.0"}
MESES_HISTORICO = 36

BCB_SERIES = {
    "IPCA_GERAL": 433,
    "IPCA_ALIMENTOS_BEBIDAS": 1635,
}

IBGE_TABELA = 8882
IBGE_VARIAVEIS = {
    7169: "PMC_HIPER_SUPER_INDICE",
    11709: "PMC_HIPER_SUPER_VAR_ANUAL",
}
IBGE_CLASSIFICACAO = "85[103154]|11046[56734]"  # Hipermercados e supermercados, indice de volume


def get_connection():
    return psycopg2.connect(
        host=os.environ["PG_HOSTNAME"],
        port=os.environ.get("PG_PORT", "5432"),
        dbname=os.environ["PG_DATABASE"],
        user=os.environ["ENRICHMENT_PG_USERNAME"],
        password=os.environ["ENRICHMENT_PG_PASSWORD"],
    )


def buscar_bcb(codigo_serie: int, meses: int):
    """Retorna lista de (data_referencia, valor) a partir da serie BCB SGS.

    O endpoint /dados/ultimos/N tem limite de 20 valores - para mais historico
    e preciso usar o endpoint de intervalo de datas (dataInicial/dataFinal).
    """
    data_inicial = date.today() - timedelta(days=meses * 31)
    url = (
        f"https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo_serie}/dados"
        f"?formato=json&dataInicial={data_inicial.strftime('%d/%m/%Y')}"
        f"&dataFinal={date.today().strftime('%d/%m/%Y')}"
    )
    response = requests.get(url, headers=HEADERS, timeout=15)
    response.raise_for_status()
    resultado = []
    for item in response.json():
        dia, mes, ano = item["data"].split("/")
        resultado.append((date(int(ano), int(mes), int(dia)), float(item["valor"])))
    return resultado


def buscar_ibge(tabela: int, variaveis: dict, classificacao: str, meses: int):
    """Retorna {indicador: [(data_referencia, valor), ...]} a partir do Agregados/IBGE."""
    ids_variaveis = "|".join(str(v) for v in variaveis)
    url = (
        f"https://servicodados.ibge.gov.br/api/v3/agregados/{tabela}"
        f"/periodos/-{meses}/variaveis/{ids_variaveis}"
        f"?localidades=N1[all]&classificacao={classificacao}"
    )
    response = requests.get(url, headers=HEADERS, timeout=15)
    response.raise_for_status()
    dados = response.json()

    resultado = {nome: [] for nome in variaveis.values()}
    for bloco in dados:
        indicador = variaveis[int(bloco["id"])]
        for serie_resultado in bloco["resultados"]:
            for serie in serie_resultado["series"]:
                for periodo, valor in serie["serie"].items():
                    if valor in ("", "..", "-"):
                        continue
                    ano, mes = int(periodo[:4]), int(periodo[4:6])
                    resultado[indicador].append((date(ano, mes, 1), float(valor)))
    return resultado


UPSERT_SQL = """
INSERT INTO bronze.indicadores_mercado_externo (data_referencia, indicador, valor, fonte, _loaded_at)
VALUES (%(data_referencia)s, %(indicador)s, %(valor)s, %(fonte)s, now())
ON CONFLICT (data_referencia, indicador) DO UPDATE SET
    valor = EXCLUDED.valor,
    fonte = EXCLUDED.fonte,
    _loaded_at = now()
"""


def gravar(conn, data_referencia, indicador, valor, fonte):
    with conn.cursor() as cur:
        cur.execute(
            UPSERT_SQL,
            {
                "data_referencia": data_referencia,
                "indicador": indicador,
                "valor": valor,
                "fonte": fonte,
            },
        )


def main():
    conn = get_connection()
    conn.autocommit = True

    total = 0

    for indicador, codigo in BCB_SERIES.items():
        pontos = buscar_bcb(codigo, MESES_HISTORICO)
        for data_referencia, valor in pontos:
            gravar(conn, data_referencia, indicador, valor, "BCB_SGS")
        print(f"{indicador}: {len(pontos)} pontos gravados (BCB SGS serie {codigo}).")
        total += len(pontos)

    ibge_resultado = buscar_ibge(IBGE_TABELA, IBGE_VARIAVEIS, IBGE_CLASSIFICACAO, MESES_HISTORICO)
    for indicador, pontos in ibge_resultado.items():
        for data_referencia, valor in pontos:
            gravar(conn, data_referencia, indicador, valor, "IBGE_SIDRA")
        print(f"{indicador}: {len(pontos)} pontos gravados (IBGE tabela {IBGE_TABELA}).")
        total += len(pontos)

    conn.close()
    print(f"\nConcluido: {total} pontos gravados.")


if __name__ == "__main__":
    try:
        main()
    except (requests.RequestException, psycopg2.Error) as e:
        print(f"ERRO: {e}", file=sys.stderr)
        sys.exit(1)
