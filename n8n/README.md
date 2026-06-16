# n8n — Workflows

Exportação dos 6 workflows de orquestração para recuperação de desastres e versionamento.

> **Atualizar sempre que um workflow for alterado no n8n UI:**
> editar no n8n → exportar JSON → substituir o arquivo aqui → commitar.

---

## Workflows

| Arquivo | Trigger | Função |
|---|---|---|
| `01-cold-disparar-hop.json` | Cron 01:00 | Dispara Hop cold (workflow_consinco.hwf) |
| `02-cold-callback-dbt-telegram.json` | Webhook `hop-finished` | Roda dbt após Hop cold → Telegram |
| `03-cold-erro.json` | Webhook `hop-error` | Notifica erro do Hop cold → Telegram |
| `04-hot-trigger-hop.json` | Cron 08h/12h/15h/18h | Dispara Hop hot (workflow_consinco_vendas_hot) |
| `05-hot-callback-dbt-telegram.json` | Webhook `vendas-hot` | Roda dbt após Hop hot → Telegram |
| `06-mensal-curva-abc-tempo-entrega.json` | Cron dia 1, 02:00 | Curva ABC + Tempo Entrega → Telegram |

---

## Como restaurar (reconstrução do zero)

### 1. Pré-requisitos no n8n

Antes de importar, criar as credenciais em **Settings → Credentials**:

| Nome da credencial | Tipo | Campo | Valor |
|---|---|---|---|
| `Trigger API Key` | Header Auth | Name: `X-Api-Key` / Value: `<TRIGGER_API_KEY>` | ver `docs/credenciais.md` |
| `Telegram Bot` | Telegram API | Token: `<TELEGRAM_BOT_TOKEN>` | ver `docs/credenciais.md` |

### 2. Importar os workflows

No n8n: **Workflows → Import from file** → importar cada JSON em ordem (01 a 06).

Após importar cada workflow com Telegram, **substituir `<TELEGRAM_CHAT_ID>`** pelo valor real
(disponível em `docs/credenciais.md` → seção Telegram).

### 3. Vincular credenciais

Em cada workflow importado, abrir os nós HTTP Request e Telegram e selecionar as credenciais criadas no passo 1.

### 4. Ativar os workflows

Ativar todos os 6 workflows. Para os que têm webhook (02, 03, 05), fazer ciclo
**deactivate → activate** para registrar os endpoints.

### 5. Verificar os webhooks

Os workflows 02, 03 e 05 usam URLs de webhook que o Hop chama ao final da extração.
Confirmar que as variáveis no Dokploy (`HOP_WEBHOOK_FINISHED_URL`, `HOP_WEBHOOK_ERROR_URL`,
`HOP_HOT_WEBHOOK_URL`) apontam para `https://n8n-webhook.modernizaai.com/webhook/<path>`.

---

## O que foi sanitizado

- `telegram_chat_id`: substituído por `<TELEGRAM_CHAT_ID>` (valor real em `docs/credenciais.md`)
- Credenciais n8n: referenciadas por tipo, não por ID — precisam ser recriadas manualmente
- IDs internos dos nós: mantidos para consistência de referências entre nós
