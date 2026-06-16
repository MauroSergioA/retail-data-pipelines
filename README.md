# retail-data-pipelines

![Apache Hop](https://img.shields.io/badge/Apache%20Hop-blue?logo=apache)
![dbt](https://img.shields.io/badge/dbt-orange?logo=dbt)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?logo=postgresql&logoColor=white)
![n8n](https://img.shields.io/badge/n8n-EA4B71?logo=n8n&logoColor=white)
![Metabase](https://img.shields.io/badge/Metabase-509EE3?logo=metabase&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![Status](https://img.shields.io/badge/status-em%20produção-green)

Pipeline de dados moderno para rede de varejo — extração do ERP Oracle, transformação
com dbt e entrega via Metabase. Infraestrutura 100% open source, containerizada e
auto-hospedada.

> **Projeto em desenvolvimento ativo.** Este documento é atualizado conforme o projeto
> avança — novas fontes, modelos e decisões são registrados aqui.

---

## Por que este projeto existe

A stack anterior rodava inteiramente sobre a infraestrutura Microsoft: Power BI com
Dataflows como camada de transformação, modelos semânticos conectados a eles e relatórios
entregues via Power BI Service.

O gatilho para a migração foi a mudança de licenciamento do Power BI: o uso de Dataflows
passou a exigir capacidade Fabric, o que representaria um aumento de custo incompatível
com a realidade do cliente neste momento.

A decisão foi migrar para uma stack open source, portátil e sem dependência de licença de
plataforma — mantendo (ou melhorando) a qualidade das entregas.

---

## Arquitetura

```
┌──────────────────────────────────────────────────────────────────────┐
│                         FONTES DE DADOS                              │
│  Oracle · Consinco ERP          SQL Server · Asseponto  🔜           │
│  API REST · Cobli  🔜           Google Sheets · Metas   🔜           │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │  JDBC / API
                                   ▼
             ┌──────────────────────────────────────────┐
             │           Apache Hop  2.10.0             │
             │   ~20 pipelines · workflow_consinco      │
             └────────────────────┬─────────────────────┘
                                  │  carga raw
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│  bronze.*  —  dados brutos, sem transformação                        │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │  dbt  (staging)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  silver.*  —  limpeza · cast · rename  (views)                       │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │  dbt  (dw)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  gold.*  —  dim_*  ·  fato_*  ·  mart_*  (tables)                   │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
             ┌──────────────────────────────────────────┐
             │          Metabase  0.50.8                │
             │       dashboards operacionais            │
             └──────────────────────────────────────────┘

  Orquestração: n8n agenda Hop (01:00 + 4×/dia) e dbt (pós-Hop + dia 1)
  Infraestrutura: Docker Swarm + Dokploy · Cloudflare Tunnel · Ubuntu local
```

### Camadas de dados

| Schema | Responsável | Conteúdo |
| --- | --- | --- |
| `bronze` | Apache Hop | Dados brutos do Oracle, sem transformação |
| `silver` | dbt (views) | Limpeza, tipagem e renomeação de colunas |
| `gold` | dbt (tables) | Dimensões, fatos e marts prontos para consumo |

Ferramentas de BI lêem exclusivamente do schema `gold` via usuário somente-leitura.
A camada de consumo é agnóstica — Metabase, Power BI e outras ferramentas conectam
sem alteração no pipeline.

---

## Decisões técnicas

### Apache Hop — extração e carga

Conectores nativos Oracle JDBC e suporte a variáveis de pipeline tornam o Hop adequado
para extração de ERPs. A alternativa seriam scripts Python — mais flexíveis, mas mais
frágeis para conexões JDBC e sem interface visual para depurar pipelines complexos.

### dbt — transformação

Toda lógica de negócio fica em arquivos `.sql` versionados, com testes embutidos
(`dbt test`), documentação automática e linhagem visual. A alternativa anterior —
transformar nos Dataflows do Power BI — criava acoplamento direto com a plataforma de
visualização e tornava as transformações invisíveis para o controle de versão.

### PostgreSQL local — armazenamento

O fato histórico de vendas acumula milhões de linhas. Soluções cloud gratuitas (Supabase,
Neon) esgotariam o storage em meses. O servidor já roda 24/7, então PostgreSQL local não
adiciona risco operacional e tem custo zero.

### Camada de BI — agnóstica por design

A camada `gold` é PostgreSQL puro — qualquer ferramenta de BI conecta via JDBC/ODBC
ou conector nativo. Atualmente o Metabase serve os dashboards operacionais pela
acessibilidade para usuários não técnicos e pelo custo zero. O Power BI Service e outras
ferramentas estão no radar para setores ou operações com necessidades específicas — a
decisão será tomada conforme o projeto amadurece. A separação entre pipeline e camada de
consumo garante que adicionar ou trocar ferramentas de BI não exige nenhuma mudança no
pipeline.

### Dokploy + Docker — infraestrutura

Deploy, rollback e variáveis de ambiente gerenciados via painel sem depender de
plataformas como Railway ou Render. Push para `main` reconstrói os containers
automaticamente via GitHub webhook.

---

## Estado atual

### Em produção

| Fonte | Tabelas carregadas | Camada |
| --- | --- | --- |
| Consinco (Oracle ERP) | 20 tabelas | bronze → silver |

| Modelo | Tipo | Status |
| --- | --- | --- |
| `dim_empresa_info` | Dimensão | ✅ produção |
| `dim_fornecedor_info` | Dimensão | ✅ produção |
| `dim_produto_info` | Dimensão | ✅ produção |
| `dim_produto_empresa` | Dimensão | ✅ produção |
| `dim_calendario` | Dimensão | ✅ produção |
| `dim_hora` | Dimensão | ✅ produção |
| `fato_venda` | Fato incremental | ✅ produção |
| `fato_entrada` | Fato incremental | ✅ produção |
| `mart_curva_abc` | Mart | ✅ produção |
| `mart_tempo_entrega_fornecedor` | Mart | ✅ produção |

### Roadmap

| Fonte | Dados | Status |
| --- | --- | --- |
| Asseponto (SQL Server) | Ponto eletrônico, RH | 🔜 planejado |
| Cobli (API REST) | Rastreamento de frota | 🔜 planejado |
| Google Sheets | Metas comerciais | 🔜 planejado |

---

## Documentação técnica

A documentação dos modelos dbt — descrições de colunas, testes, linhagem e fontes —
é gerada automaticamente e publicada em:

> 🔗 *dbt docs — em breve*

---

## Stack

| Camada | Ferramenta | Versão |
| --- | --- | --- |
| Extração | Apache Hop | 2.10.0 |
| Transformação | dbt Core | 1.12.0-b1 |
| Armazenamento | PostgreSQL | 18 |
| BI | Metabase | 0.50.8 |
| Orquestração | n8n | 2.25.6 |
| Deploy | Dokploy | 0.29.7 |
| Tunnel | Cloudflare Tunnel (cloudflared) | — |

---

## Estrutura do repositório

```text
retail-data-pipelines/
├── Dockerfile              # Hop trigger server (Alpine + Python3 + su-exec + ojdbc8)
├── Dockerfile.dbt          # dbt runner (Python 3.12-slim)
├── .env.example            # Variáveis necessárias (sem valores reais)
├── consinco/               # Pipelines Hop (.hpl) — uma por tabela Oracle
├── workflows/
│   ├── workflow_consinco.hwf             # Workflow cold (~20 tabelas Oracle → bronze)
│   └── workflow_consinco_vendas_hot.hwf  # Workflow hot (vendas + entradas, 4×/dia)
├── metadata/
│   └── rdbms/              # Conexões Hop (postgresql-server, oracle-consinco)
├── transform/              # Projeto dbt completo
│   ├── dbt_project.yml
│   ├── macros/
│   └── models/
│       ├── staging/consinco/   # stg_* — silver layer
│       └── dw/                 # dim_*, fato_*, mart_* — gold layer
├── scripts/
│   ├── docker-entrypoint.sh    # Wrapper root: injeta host.docker.internal, exec como hop
│   ├── hop-entrypoint.sh       # Registra projeto/env no Hop + inicia trigger server
│   ├── hop-run-server.py       # HTTP server :8080 → executa hop-run.sh
│   ├── init-hop-vars.sh        # Gera /tmp/hop-env.json com env vars do Docker
│   ├── dbt-server.py           # HTTP server :8000 → executa dbt run
│   ├── init-dbt.sh             # Gera ~/.dbt/profiles.yml a partir de env vars
│   └── setup/
│       └── 01_pg_dbt_user.sql  # Criação de usuários PostgreSQL
└── compose/
    ├── n8n.yml                 # n8n queue mode (main + worker + runner + Redis)
    ├── metabase.yml            # Metabase com backend PostgreSQL
    └── cloudflared.yml         # Cloudflare Tunnel (network_mode: host)
```

---

## Configuração

Copie `.env.example` e configure as variáveis no Dokploy para cada serviço.

| Grupo | Descrição | Serviço |
| --- | --- | --- |
| `PG_*` | PostgreSQL — host, porta, database, usuário, senha, JDBC URL | hop-server, dbt-runner |
| `CONSINCO_*` | Oracle ERP — host, porta, service name, usuário, senha, JDBC URL | hop-server |
| `HOP_OPTIONS` | JVM memory (ex: `-Xmx3g`) | hop-server |
| `HOP_WEBHOOK_FINISHED_URL` | URL do webhook n8n acionado ao fim da extração | hop-server |
| `DBT_*` | Usuário e senha dbt no PostgreSQL | dbt-runner |
| `TRIGGER_API_KEY` | Chave de autenticação dos servidores Hop e dbt (header `X-Api-Key`) | hop-server, dbt-runner |
| `N8N_*` | Host, DB, encryption key, JWT secret, runners secret | n8n |
| `MB_*` | Database, usuário e senha do Metabase | metabase |

---

## APIs dos trigger servers

Chamadas `POST /run` requerem o header `X-Api-Key: <TRIGGER_API_KEY>`. O endpoint `/health` é público.

### hop-run-server.py — porta 8080

| Endpoint | Método | Descrição |
| --- | --- | --- |
| `/run` | POST | Inicia `workflow_consinco.hwf` em background. Retorna `{"status":"started"}` imediatamente. Retorna 409 se já estiver rodando. |
| `/health` | GET | `{"status":"idle"}` ou `{"status":"running"}` |

### dbt-server.py — porta 8000

| Endpoint | Método | Descrição |
| --- | --- | --- |
| `/run` | POST | Executa `dbt run --target prod`. Retorna JSON com `returncode`, `stdout`, `stderr`. |
| `/run?select=model` | POST | Executa modelo específico. |
| `/health` | GET | `{"status":"ok"}` |

---

## Networking Docker

Compose e Swarm usam DNS separados — containers Compose não resolvem nomes de Swarm
services. Solução adotada:

- Swarm services expõem portas via ingress mesh → acessíveis em `localhost:<porta>` no host
- Containers Compose usam `host.docker.internal` para chamar serviços Swarm
- `n8n-worker` precisa de `extra_hosts: ["host.docker.internal:host-gateway"]`
- Variáveis Docker não são expostas automaticamente ao Hop — precisam ser declaradas
  em `init-hop-vars.sh` para constar no `hop-env.json`
