# Visão Geral da Arquitetura

## O que é este projeto

Retail Analytics é o data warehouse operacional da rede de varejo. O objetivo é centralizar
dados de todas as fontes (ERP, RH, frota, metas manuais) em um único lugar confiável,
com transformações documentadas e auditáveis, alimentando relatórios no Power BI.

O projeto foi construído do zero em 2026 para substituir um projeto anterior que havia
se tornado híbrido e difícil de manter.

---

## Fluxo de dados

```
Fontes externas
(Oracle, SQL Server, API REST, Google Sheets)
        │
        │  Apache Hop — extração e carga (E+L)
        ▼
raw.*  ←── dado bruto, exatamente como veio da fonte
        │
        │  dbt — transformação (T)
        ▼
staging.*  ←── limpeza, tipagem, renomeação de colunas
        │
        │  dbt
        ▼
dw.*  ←── fatos e dimensões prontos para consumo
        │
        │  Power BI Gateway
        ▼
Power BI Service  ←── relatórios e dashboards
```

---

## Princípios fundamentais

**Hop faz apenas E+L.** Os pipelines extraem da fonte e carregam no `raw` sem nenhuma
transformação. Lógica de negócio em pipeline XML é impossível de manter e de versionar.

**Toda lógica fica no dbt.** Cada transformação é um arquivo `.sql` com nome significativo,
testável com `dbt test`, documentável com `.yml` e rastreável via `dbt docs`.

**Power BI não transforma dados.** O modelo semântico lê dimensões e fatos prontos do
schema `dw`. Medidas DAX fazem apenas agregações e cálculos de apresentação.

**Sem `NOT IN (3, 4)` em nenhum lugar.** As lojas 3 e 4 encerraram operações mas seus
dados históricos são preservados. Filtro de loja ativa é feito no relatório via coluna
`status = 'A'` em `dim_empresa_info`.

---

## Decisões de stack

### Por que PostgreSQL local e não cloud?

`fato_venda` acumula ~3M linhas (3 anos). Supabase free (500 MB) esgotaria em poucos meses.
A máquina já roda 24/7 pelo gateway do Power BI — PostgreSQL local não adiciona risco
operacional e tem custo zero.

### Por que dbt e não transformar no Hop?

Transformações no Hop ficam em XML sem diff legível — impossível revisar, testar ou
colaborar. dbt transforma cada modelo em um arquivo `.sql` simples com testes embutidos,
documentação automática e linhagem visual.

### Por que Apache Hop e não outro ETL?

Hop tem conectores nativos para Oracle JDBC e SQL Server, suporta variáveis de pipeline
(fundamental para a janela rolling do `fato_venda`) e roda localmente sem custo.
A alternativa seria scripts Python — mais flexível mas mais frágil para conexões JDBC.

### Por que monorepo?

Pipelines Hop, modelos dbt e relatórios Power BI evoluem juntos. Um único repositório
facilita o rastreamento de mudanças end-to-end: um commit pode incluir o pipeline,
o modelo dbt e o relatório que usa o dado.

---

## Schemas PostgreSQL

| Schema | Responsável | Conteúdo |
|--------|-------------|---------|
| `raw` | Apache Hop | Dado bruto, exato como veio da fonte. Tabelas de dimensão são TRUNCATE+INSERT a cada run. Fatos são buffers rolling (janela recente). |
| `staging` | dbt (views) | Limpeza, cast de tipos, renomeação snake_case. Views — sem custo de storage. |
| `dw` | dbt (tables) | Fatos, dimensões e marts prontos. Dimensões são recriadas a cada run. Fatos são incrementais (acumulam histórico). Marts são tabelas analíticas derivadas dos fatos — pré-calculadas para consumo por múltiplas ferramentas. |

---

## Usuário PostgreSQL

O dbt usa um usuário dedicado `dbt` (sem superuser):

- `SELECT` em `raw.*`
- `CREATE` e `ALL` em `staging.*` e `dw.*`

Credenciais em `~/.dbt/profiles.yml` (gitignored).

---

## Ambiente

| Ferramenta | Versão | Observação |
|-----------|--------|-----------|
| PostgreSQL | 18 | Porta 5432 |
| dbt-postgres | 1.10.0 | venv em `C:\venv\dbt` |
| dbt-core | 1.12.0b1 | Incluído no venv |
| Apache Hop | — | Projeto `retail`, environment `prod` |
| Python | 3.13 | Microsoft Store |

Para ativar o dbt no terminal:

```powershell
$env:PATH = "C:\venv\dbt\Scripts;$env:PATH"
```
