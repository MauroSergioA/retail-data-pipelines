# retail-data-pipelines — Contexto do Projeto

Plataforma de dados para rede de supermercados (~12 lojas). Extrai do ERP Oracle (Consinco),
transforma com dbt e entrega via Metabase. Toda a infraestrutura roda em Docker no servidor
Linux (Dokploy). Repo público — credenciais e IPs internos NUNCA no código.

---

## Stack

| Camada | Ferramenta | Versão | Porta |
|---|---|---|---|
| Extração | Apache Hop | 2.10.0 | 8080 (trigger HTTP) |
| Transformação | dbt Core | 1.12.0-b1 | 8000 (trigger HTTP) |
| Armazenamento | PostgreSQL | 18 | — |
| BI | Metabase | 0.50.8 | 3001 |
| Orquestração | n8n | 2.25.6 | 5678 |
| Deploy | Dokploy | — | 3000 |
| Tunnel | Cloudflare Tunnel | — | — |

---

## Schemas PostgreSQL

| Schema | Responsável | Conteúdo |
|---|---|---|
| `bronze` | Hop | Carga raw direta do Oracle |
| `silver` | dbt | Staging — limpeza e tipagem |
| `gold` | dbt | Dimensões, fatos, marts |

Usuário `metabase_reader` tem acesso somente-leitura em `gold`.

---

## Fluxo completo do pipeline (produção)

```
n8n Agendamento (01:00)
  → POST http://host.docker.internal:8080/run        ← hop-run-server.py
    → hop-run.sh executa workflow_diario.hwf
      → extrai todas as tabelas Oracle → bronze
      → ao final: POST https://n8n-webhook.modernizaai.com/webhook/hop-finished
        → n8n Pipeline Diário
          → POST http://host.docker.internal:8000/run  ← dbt-server.py
            → dbt run (bronze → silver → gold)
              → Telegram @SuperqueOps_bot
```

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
│   ├── hop-entrypoint.sh   # Entrypoint: registra projeto/env + inicia trigger server
│   ├── hop-run-server.py   # HTTP server porta 8080 → executa hop-run.sh
│   ├── init-hop-vars.sh    # Gera /tmp/hop-env.json com env vars do Docker
│   ├── dbt-server.py       # HTTP server porta 8000 → executa dbt run
│   ├── init-dbt.sh         # Setup inicial dbt (profiles, packages)
│   └── setup/
│       └── 01_pg_dbt_user.sql  # Criação de usuários PostgreSQL
├── compose/
│   ├── n8n.yml             # n8n queue mode (main + worker + runner + Redis)
│   └── metabase.yml        # Metabase com backend PostgreSQL
└── docs/
    ├── arquitetura/        # Visão geral, convenções, estratégias
    ├── dw/                 # Documentação de cada modelo gold
    ├── fontes/             # Documentação das tabelas Oracle
    └── guias/              # Guias operacionais
```

---

## Serviços no Dokploy

| Serviço | Tipo | Repo/Dockerfile | Descrição |
|---|---|---|---|
| hop-server | Docker Swarm | `Dockerfile` | Hop trigger server |
| dbt-runner | Docker Swarm | `Dockerfile.dbt` | dbt trigger server |
| n8n | Docker Compose | `compose/n8n.yml` | Orquestração (queue mode) |
| metabase | Docker Compose | `compose/metabase.yml` | BI |

### Autodeploy
Push para `main` → GitHub webhook → Dokploy reconstrói `hop-server` e `dbt-runner`.
**Atenção:** qualquer push reconstrói — não commitar enquanto pipeline estiver rodando.

---

## Networking Docker (ponto crítico)

Docker Compose e Docker Swarm usam DNS separados — containers Compose não resolvem
nomes de Swarm services. Solução adotada:

1. Swarm services expõem portas via **INGRESS routing mesh** → acessíveis em `localhost:<porta>` no host
2. Containers Compose usam `host.docker.internal` para chamar serviços Swarm:
   - Hop: `http://host.docker.internal:8080/run`
   - dbt: `http://host.docker.internal:8000/run`
3. **Importante:** `n8n-worker` executa os HTTP Request nodes (não o `n8n` main). Ambos precisam de `extra_hosts: ["host.docker.internal:host-gateway"]`.
4. **Nunca** usar `docker service update --network-add` em serviços gerenciados pelo Dokploy — ele reverte.

---

## APIs dos trigger servers

### hop-run-server.py (porta 8080)
- `POST /run` → inicia `workflow_diario.hwf` em background, retorna `{"status":"started"}` imediatamente
- `GET /health` → retorna `{"status":"idle"}` ou `{"status":"running"}`
- Previne execuções concorrentes (retorna 409 se já estiver rodando)

### dbt-server.py (porta 8000)
- `POST /run` → executa `dbt run --target prod`, retorna JSON com `returncode`, `stdout`, `stderr`
- `POST /run?select=model_name` → executa modelo específico
- `GET /health` → `{"status":"ok"}`

---

## Variáveis de ambiente necessárias

Ver `.env.example` para a lista completa. Configuradas no Dokploy para cada serviço.
Grupos principais:
- `PG_*` — PostgreSQL (host, porta, database, usuário, senha, URL JDBC)
- `CONSINCO_*` — Oracle ERP (host, porta, service name, usuário, senha, URL JDBC)
- `HOP_OPTIONS` — JVM memory para Hop (`-Xmx3g`)
- `DBT_*` — usuário/senha dbt no PostgreSQL
- `N8N_*` — configuração n8n (host, DB, encryption key, JWT secret, runners secret)
- `MB_*` — configuração Metabase (DB name, usuário, senha)

---

## Modelos dbt ativos (gold layer)

| Modelo | Tipo | Descrição |
|---|---|---|
| `dim_empresa_info` | Dimensão | Lojas ativas/inativas |
| `dim_fornecedor_info` | Dimensão | Fornecedores |
| `dim_produto_info` | Dimensão | Produtos com atributos |
| `dim_produto_empresa` | Dimensão | Produto × Loja (preços, estoque, promoções) |
| `fato_venda` | Fato incremental | Vendas diárias |
| `mart_curva_abc` | Mart | Classificação ABC de produtos |

---

## Regras de negócio críticas

**Lojas inativas:** Nunca filtrar `nroempresa NOT IN (3, 4)`. Usar `status_empresa = 'ATIVA'`
de `dim_empresa_info`. Lojas 3 e 4 encerraram mas têm dados históricos.

**Segmento de preço:** Nunca filtrar `nrosegmento = 1` em `mrl_prodempseg`. Fazer JOIN com
`max_empresa.nrosegmentoprinc` para obter o segmento correto de cada loja.

**Categoria (`etlv_categoria`):** Granularidade é `(nrodivisao, seqfamilia)`. Nunca filtrar
`WHERE nrodivisao = 1` — famílias exclusivas de outras divisões seriam perdidas. Usar
`ROW_NUMBER()` priorizando `nrodivisao = 1` com fallback para a menor divisão.

**Operações válidas:** Venda: `cod_geral_oper_venda IN (800, 810, 820, 828)`.
Devolução: `cod_geral_oper_devolucao IN (202)`.

---

## Troubleshooting

### Oracle: connection refused do container
Verificar se o IP do servidor Linux está na Security List do Oracle Cloud para porta 1521.
Testar do host: `nc -zv <oracle-host> 1521`

### n8n webhook retorna 404
O workflow "Pipeline Diário" precisa estar **Published/Active**. Após restart do n8n,
fazer ciclo deactivate → activate para re-registrar o webhook.

### hop-run-server retorna 409
Workflow já está rodando. Aguardar conclusão ou verificar logs do hop-server no Dokploy.

### Hop: "workflow not found" via API
O endpoint `startWorkflow` do Hop Server requer pré-registro. Este projeto usa
`hop-run-server.py` com `hop-run.sh` em vez da API nativa do Hop Server.