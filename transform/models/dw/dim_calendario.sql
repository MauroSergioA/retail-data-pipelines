{{ config(materialized='table') }}

-- Intervalo: 2018-01-01 até 5 anos à frente do dia corrente.
-- Para estender o horizonte, ajuste apenas a data de fim na CTE "spine".
-- Para adicionar/remover feriados fixos, edite seeds/feriados_fixos.csv e rode: dbt seed

WITH

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. SPINE — sequência de todas as datas do intervalo
-- ─────────────────────────────────────────────────────────────────────────────
spine AS (
    SELECT gs::DATE AS data
    FROM generate_series(
        '2018-01-01'::DATE,
        (CURRENT_DATE + INTERVAL '5 years')::DATE,
        '1 day'::INTERVAL
    ) gs
),

anos AS (
    SELECT DISTINCT EXTRACT(YEAR FROM data)::INTEGER AS ano
    FROM spine
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FERIADOS FIXOS — seed expandido para cada ano do intervalo
-- ─────────────────────────────────────────────────────────────────────────────
feriados_fixos_exp AS (
    SELECT
        make_date(a.ano, f.mes, f.dia)  AS data,
        f.nome
    FROM {{ ref('feriados_fixos') }} f
    CROSS JOIN anos a
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. PÁSCOA — algoritmo de Butcher (Gregoriano), variáveis nomeadas per spec
--    Referência: https://en.wikipedia.org/wiki/Date_of_Easter#Anonymous_Gregorian_algorithm
-- ─────────────────────────────────────────────────────────────────────────────
_p1 AS (
    SELECT ano,
           ano % 19                                         AS a,
           ano / 100                                        AS b,
           ano % 100                                        AS c
    FROM anos
),
_p2 AS (
    SELECT ano, a, b, c,
           b / 4                                            AS d,
           b % 4                                            AS e,
           (b + 8) / 25                                     AS f
    FROM _p1
),
_p3 AS (
    SELECT ano, a, b, c, d, e,
           (b - f + 1) / 3                                  AS g,
           c / 4                                            AS i,
           c % 4                                            AS k
    FROM _p2
),
_p4 AS (
    SELECT ano, a, b, d, e, i, k,
           (19 * a + b - d - g + 15) % 30                   AS h
    FROM _p3
),
_p5 AS (
    SELECT ano, a, h, e, i, k,
           (32 + 2 * e + 2 * i - h - k) % 7                 AS l
    FROM _p4
),
_p6 AS (
    SELECT ano, h, l,
           (a + 11 * h + 22 * l) / 451                      AS m
    FROM _p5
),
pascoa AS (
    SELECT
        ano,
        make_date(
            ano,
            (h + l - 7 * m + 114) / 31,
            ((h + l - 7 * m + 114) % 31) + 1
        ) AS data_pascoa
    FROM _p6
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. FERIADOS MÓVEIS — derivados da Páscoa
--    Carnaval = Terça-feira (feriado nacional). Segunda de Carnaval é ponto
--    facultativo federal mas não feriado — omitida intencionalmente.
-- ─────────────────────────────────────────────────────────────────────────────
feriados_moveis AS (
    SELECT (data_pascoa - 47)::DATE  AS data, 'Carnaval'               AS nome FROM pascoa
    UNION ALL
    SELECT (data_pascoa - 2)::DATE,            'Sexta-feira da Paixão'          FROM pascoa
    UNION ALL
    SELECT (data_pascoa + 60)::DATE,           'Corpus Christi'                 FROM pascoa
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. TODOS OS FERIADOS — union com deduplicação por data
--    Em caso de coincidência rara (feriado fixo + móvel), os nomes são concatenados
-- ─────────────────────────────────────────────────────────────────────────────
todos_feriados AS (
    SELECT
        data,
        STRING_AGG(nome, ' / ' ORDER BY nome) AS nome
    FROM (
        SELECT data, nome FROM feriados_fixos_exp
        UNION ALL
        SELECT data, nome FROM feriados_moveis
    ) t
    GROUP BY data
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. NOMES EM PORTUGUÊS — independente do locale do servidor PostgreSQL
--    Para alterar nomenclatura (ex: "Qua" → "Qua."), edite apenas este bloco
-- ─────────────────────────────────────────────────────────────────────────────
nomes_pt AS (
    SELECT
        data,
        CASE EXTRACT(MONTH FROM data)::INTEGER
            WHEN 1  THEN 'Janeiro'    WHEN 2  THEN 'Fevereiro' WHEN 3  THEN 'Março'
            WHEN 4  THEN 'Abril'      WHEN 5  THEN 'Maio'      WHEN 6  THEN 'Junho'
            WHEN 7  THEN 'Julho'      WHEN 8  THEN 'Agosto'    WHEN 9  THEN 'Setembro'
            WHEN 10 THEN 'Outubro'    WHEN 11 THEN 'Novembro'  WHEN 12 THEN 'Dezembro'
        END                                                     AS mes_nome,
        CASE EXTRACT(MONTH FROM data)::INTEGER
            WHEN 1  THEN 'Jan'  WHEN 2  THEN 'Fev'  WHEN 3  THEN 'Mar'
            WHEN 4  THEN 'Abr'  WHEN 5  THEN 'Mai'  WHEN 6  THEN 'Jun'
            WHEN 7  THEN 'Jul'  WHEN 8  THEN 'Ago'  WHEN 9  THEN 'Set'
            WHEN 10 THEN 'Out'  WHEN 11 THEN 'Nov'  WHEN 12 THEN 'Dez'
        END                                                     AS mes_nome_abrev,
        CASE EXTRACT(ISODOW FROM data)::INTEGER
            WHEN 1 THEN 'Segunda-feira'  WHEN 2 THEN 'Terça-feira'
            WHEN 3 THEN 'Quarta-feira'   WHEN 4 THEN 'Quinta-feira'
            WHEN 5 THEN 'Sexta-feira'    WHEN 6 THEN 'Sábado'
            WHEN 7 THEN 'Domingo'
        END                                                     AS dia_semana_nome,
        CASE EXTRACT(ISODOW FROM data)::INTEGER
            WHEN 1 THEN 'Seg'  WHEN 2 THEN 'Ter'  WHEN 3 THEN 'Qua'
            WHEN 4 THEN 'Qui'  WHEN 5 THEN 'Sex'  WHEN 6 THEN 'Sáb'
            WHEN 7 THEN 'Dom'
        END                                                     AS dia_semana_abrev
    FROM spine
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. BASE — atributos de cada data
-- ─────────────────────────────────────────────────────────────────────────────
base AS (
    SELECT
        s.data,

        -- período em relação a hoje (recalculado diariamente no cold run)
        CASE
            WHEN s.data < CURRENT_DATE THEN 'Passado'
            WHEN s.data = CURRENT_DATE THEN 'Presente'
            ELSE                            'Futuro'
        END                                                     AS periodo,

        -- ano
        EXTRACT(YEAR FROM s.data)::INTEGER                      AS ano_num,

        -- trimestre
        EXTRACT(QUARTER FROM s.data)::INTEGER                   AS trimestre_num,

        -- mês
        EXTRACT(MONTH FROM s.data)::INTEGER                     AS mes_num,
        n.mes_nome,
        n.mes_nome_abrev,
        n.mes_nome_abrev || '/' || TO_CHAR(s.data, 'YY')       AS mes_ano_nome,

        -- semana ISO (ano ISO pode diferir do calendário nos primeiros/últimos dias do ano)
        EXTRACT(ISOYEAR FROM s.data)::INTEGER                   AS ano_iso_num,
        EXTRACT(WEEK    FROM s.data)::INTEGER                   AS semana_iso_num,

        -- dia
        EXTRACT(DAY    FROM s.data)::INTEGER                    AS dia_mes_num,
        EXTRACT(ISODOW FROM s.data)::INTEGER                    AS dia_semana_num,
        n.dia_semana_nome,
        n.dia_semana_abrev,

        -- fim de semana (Sáb=6, Dom=7 no padrão ISO)
        (EXTRACT(ISODOW FROM s.data) >= 6)                      AS ind_fim_semana,

        -- feriado
        f.nome                                                  AS feriado_nome,
        (f.nome IS NOT NULL)                                    AS ind_feriado,

        -- dia útil convencional: seg-sex sem feriado nacional
        (EXTRACT(ISODOW FROM s.data) <= 5 AND f.nome IS NULL)   AS dia_util,

        -- dia útil da rede: todos os dias exceto 01/jan e 01/mai (únicas datas em que
        -- todas as lojas fecham); inclui fins de semana pois lojas operam sábado e domingo.
        -- Usado como denominador para calcular média diária de vendas da rede.
        NOT (
            (EXTRACT(MONTH FROM s.data) = 1 AND EXTRACT(DAY FROM s.data) = 1)
            OR
            (EXTRACT(MONTH FROM s.data) = 5 AND EXTRACT(DAY FROM s.data) = 1)
        )                                                       AS dia_util_rede,

        -- faixa comercial do mês (décadas)
        CASE
            WHEN EXTRACT(DAY FROM s.data) <= 10 THEN '01-10'
            WHEN EXTRACT(DAY FROM s.data) <= 24 THEN '11-24'
            ELSE                                     '25-FIM'
        END                                                     AS faixa_mes,

        -- data equivalente no ano anterior alinhada por semana ISO (mesmo dia da semana,
        -- mesma semana ISO) — 364 dias = 52 semanas exatas, preserva o dia da semana
        (s.data - INTERVAL '364 days')::DATE                    AS data_equivalente_aa

    FROM spine s
    LEFT JOIN nomes_pt       n ON n.data = s.data
    LEFT JOIN todos_feriados f ON f.data = s.data
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. MÉTRICAS DO MÊS — requerem segunda passagem sobre base (window functions)
-- ─────────────────────────────────────────────────────────────────────────────
metricas_mes AS (
    SELECT
        data,

        -- sequência do dia ativo da rede dentro do mês (1 = primeiro dia do mês que rede opera)
        -- NULL apenas em 01/jan e 01/mai (únicos dias com fechamento universal)
        -- inclui fins de semana pois lojas operam — base para cálculo de tendência de meta
        CASE WHEN dia_util_rede
            THEN SUM(dia_util_rede::INTEGER) OVER (
                    PARTITION BY ano_num, mes_num
                    ORDER BY data
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                )
        END                                                     AS dia_util_seq_mes,

        -- total de dias ativos da rede no mês
        SUM(dia_util_rede::INTEGER) OVER (
            PARTITION BY ano_num, mes_num
        )                                                       AS dia_util_total_mes,

        -- dias ativos da rede restantes no mês a partir desta data (inclusive)
        -- countdown: 30 no dia 1, 1 no último dia; não depende de CURRENT_DATE
        COALESCE(
            SUM(dia_util_rede::INTEGER) OVER (
                PARTITION BY ano_num, mes_num
                ORDER BY data
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ),
        0)                                                      AS dia_util_restante_mes

    FROM base
)

-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT FINAL
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    b.data,
    b.periodo,

    b.ano_num,
    b.trimestre_num,

    b.mes_num,
    b.mes_nome,
    b.mes_nome_abrev,
    b.mes_ano_nome,

    b.ano_iso_num,
    b.semana_iso_num,

    b.dia_mes_num,
    b.dia_semana_num,
    b.dia_semana_nome,
    b.dia_semana_abrev,

    b.ind_fim_semana,
    b.feriado_nome,
    b.ind_feriado,

    b.dia_util,
    b.dia_util_rede,

    b.faixa_mes,
    m.dia_util_seq_mes,
    m.dia_util_total_mes,
    m.dia_util_restante_mes,

    b.data_equivalente_aa

FROM base b
JOIN metricas_mes m ON m.data = b.data
ORDER BY b.data
