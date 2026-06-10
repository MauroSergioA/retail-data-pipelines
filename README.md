# retail-data-pipelines

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
n8n (01:00)
  → POST :8080/run              ← hop-run-server.py
    → hop-run.sh executa workflow_diario.hwf
      → extrai tabelas Oracle → bronze (PostgreSQL)
      → POST ${HOP_WEBHOOK_FINISHED_URL}
        → n8n Pipeline Diário
          → POST :8000/run      ← dbt-server.py
            → dbt run (bronze → silver → gold)
              → notificação Telegram
```

### Camadas de dados

| Schema | Responsável | Conteúdo |
|---|---|---|
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
|---|---|---|
| Consinco (Oracle ERP) | 20 tabelas | bronze → silver |

| Modelo | Tipo | Status |
|---|---|---|
| `dim_empresa_info` | Dimensão | ✅ produção |
| `dim_fornecedor_info` | Dimensão | ✅ produção |
| `dim_produto_info` | Dimensão | ✅ produção |
| `dim_produto_empresa` | Dimensão | ✅ produção |
| `fato_venda` | Fato incremental | ✅ produção |
| `mart_curva_abc` | Mart | ✅ produção |

### Roadmap

| Fonte | Dados | Status |
|---|---|---|
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
|---|---|---|
| Extração | Apache Hop | 2.10.0 |
| Transformação | dbt Core | 1.12.0-b1 |
| Armazenamento | PostgreSQL | 18 |
| BI | Metabase | 0.50.8 |
| Orquestração | n8n | 2.25.6 |
| Deploy | Dokploy | — |
| Tunnel | Cloudflare Tunnel | — |

---

## Estrutura do repositório

```
retail-data-pipelines/
├── Dockerfile              # Hop trigger server (Alpine + Python3 + ojdbc8)
├── Dockerfile.dbt          # dbt runner (Python 3.12-slim)
├── .env.example            # Variáveis necessárias (sem valores reais)
├── consinco/               # Pipelines Hop (.hpl) — uma por tabela Oracle
├── workflows/
│   └── workflow_diario.hwf # Workflow principal diário
├── metadata/
│   └── rdbms/              # Conexões Hop (postgresql-server, oracle-consinco)
├── transform/              # Projeto dbt completo
│   ├── dbt_project.yml
│   ├── macros/
│   └── models/
│       ├── staging/consinco/   # stg_* — silver layer
│       └── dw/                 # dim_*, fato_*, mart_* — gold layer
├── scripts/
│   ├── hop-entrypoint.sh       # Registra projeto/env no Hop + inicia trigger server
│   ├── hop-run-server.py       # HTTP server :8080 → executa hop-run.sh
│   ├── init-hop-vars.sh        # Gera /tmp/hop-env.json com env vars do Docker
│   ├── dbt-server.py           # HTTP server :8000 → executa dbt run
│   ├── init-dbt.sh             # Gera ~/.dbt/profiles.yml a partir de env vars
│   └── setup/
│       └── 01_pg_dbt_user.sql  # Criação de usuários PostgreSQL
└── compose/
    ├── n8n.yml                 # n8n queue mode (main + worker + runner + Redis)
    └── metabase.yml            # Metabase com backend PostgreSQL
```

---

## Configuração

Copie `.env.example` e configure as variáveis no Dokploy para cada serviço.

| Grupo | Descrição | Serviço |
|---|---|---|
| `PG_*` | PostgreSQL — host, porta, database, usuário, senha, JDBC URL | hop-server, dbt-runner |
| `CONSINCO_*` | Oracle ERP — host, porta, service name, usuário, senha, JDBC URL | hop-server |
| `HOP_OPTIONS` | JVM memory (ex: `-Xmx3g`) | hop-server |
| `HOP_WEBHOOK_FINISHED_URL` | URL do webhook n8n acionado ao fim da extração | hop-server |
| `DBT_*` | Usuário e senha dbt no PostgreSQL | dbt-runner |
| `N8N_*` | Host, DB, encryption key, JWT secret, runners secret | n8n |
| `MB_*` | Database, usuário e senha do Metabase | metabase |

---

## APIs dos trigger servers

### hop-run-server.py — porta 8080

| Endpoint | Método | Descrição |
|---|---|---|
| `/run` | POST | Inicia `workflow_diario.hwf` em background. Retorna `{"status":"started"}` imediatamente. Retorna 409 se já estiver rodando. |
| `/health` | GET | `{"status":"idle"}` ou `{"status":"running"}` |

### dbt-server.py — porta 8000

| Endpoint | Método | Descrição |
|---|---|---|
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
