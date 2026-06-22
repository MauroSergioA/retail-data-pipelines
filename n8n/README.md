# n8n — Workflows

Exportação dos 7 workflows de orquestração para recuperação de desastres e versionamento.

> **Atualizar sempre que um workflow for alterado no n8n UI:**
> editar no n8n → exportar JSON → substituir o arquivo aqui → commitar.

---

## Workflows

| Arquivo | Trigger | Função |
|---|---|---|
| `01-cold-disparar-hop.json` | Cron 01:00 | Dispara Hop cold (workflow_consinco_cold.hwf) |
| `02-cold-callback-dbt-telegram.json` | Webhook `hop-finished` | Roda dbt após Hop cold → Telegram |
| `03-cold-erro.json` | Webhook `hop-error` + Error Trigger | Notifica erro do Hop cold → Telegram. Também serve como **error workflow genérico** (qualquer workflow com `settings.errorWorkflow` apontando pro id desta, dispara o nó `Error Trigger` em caso de falha não tratada) |
| `04-hot-trigger-hop.json` | Cron 08h/12h/15h/18h | Dispara Hop hot (workflow_consinco_hot) |
| `05-hot-callback-dbt-telegram.json` | Webhook `vendas-hot` | Roda dbt após Hop hot → Telegram |
| `06-mensal-curva-abc-tempo-entrega.json` | Cron dia 1, 02:00 | Curva ABC + Tempo Entrega → Telegram |
| `08-fornecedores-cnpj-mensal-full.json` | Cron dia 1, 03:00 | Enriquecimento de CNPJ full (reprocessa tudo) → Telegram |

> Não existe mais um `07`: era o "Enriquecer CNPJ (diário)" standalone, **excluído** em
> 2026-06-22 — a lógica (chamada `/run-cnpj` + checagem + notificação) foi migrada pro
> workflow 02, ver nota abaixo. A numeração ficou com esse buraco de propósito (histórico).

### Notas operacionais (2026-06-22)

- **Timeout do nó "Executar dbt" (workflow 02):** aumentado de 30min para **90min**
  (`5400000`ms). O `dbt run` cold já chegou a levar ~46min em produção (cresceu com a
  adição de `fato_pedido_compra` + volume normal de dados) — o timeout antigo de 30min
  abortava a chamada HTTP antes do dbt terminar, e como o dbt continua rodando em
  background mesmo com o cliente desconectado, os dados atualizavam normalmente mas a
  notificação do Telegram nunca era enviada (a etapa "Notificar Sucesso/Falha" nunca era
  alcançada). Se o cold continuar crescendo, revisar esse timeout de novo.
- **`settings.errorWorkflow` no workflow 02:** configurado para apontar pro id real do
  workflow 03 (visível só no n8n live, não no JSON exportado aqui — ver seção de
  restauração). Cobre o caso do item acima: se "Executar dbt" falhar/expirar de novo,
  o `Error Trigger` do workflow 03 dispara um alerta genérico no Telegram, em vez de
  falhar silenciosamente.
- **`parse_mode: "none"` no nó "Notificar Erro" do 08** (e no equivalente "Notificar Erro
  CNPJ" dentro do 02): esses nós mandam o `stdout`/`stderr` bruto do script Python no
  Telegram. Sem `parse_mode` explícito o Telegram tentava interpretar o texto como
  Markdown e travava com `Bad Request: can't parse entities` sempre que o traceback tinha
  caracteres como `_` ou `*` — ironicamente quebrando o próprio alerta de erro. Com
  `parse_mode: "none"` o texto vai sempre como plano, sem essa fragilidade.
- **CNPJ diário migrado pro fluxo do 02 — corrige corrida de horário:** existia um
  workflow `07 · Enriquecer CNPJ (diário)` standalone, num cron fixo de 02:30, sem saber
  se o `dbt run` cold já tinha terminado de recriar `gold.dim_fornecedor_info`. Num
  incidente real, o cold só terminou às 02:31:47 — 1min *depois* do CNPJ já ter disparado.
  Em vez de só aumentar a margem de segurança do cron, a chamada `/run-cnpj` (+ checagem
  `returncode` + notificação) foi movida pra dentro do workflow 02 (nós "Enriquecer CNPJ
  (diário)" → "CNPJ Sucesso?" → "Notificar Sucesso/Erro CNPJ"), disparando em paralelo com
  "Notificar Sucesso" só depois do "dbt Sucesso?" confirmar sucesso de fato. O workflow 07
  standalone foi **excluído** (não só desativado) em 2026-06-22.

---

## Como restaurar (reconstrução do zero)

### 1. Pré-requisitos no n8n

Antes de importar, criar as credenciais em **Settings → Credentials**:

| Nome da credencial | Tipo | Campo | Valor |
|---|---|---|---|
| `Trigger API Key` | Header Auth | Name: `X-Api-Key` / Value: `<TRIGGER_API_KEY>` | ver `docs/credenciais.md` |
| `Telegram Bot` | Telegram API | Token: `<TELEGRAM_BOT_TOKEN>` | ver `docs/credenciais.md` |

### 2. Importar os workflows

No n8n: **Workflows → Import from file** → importar cada JSON (01 a 06, depois 08 —
não existe 07, ver nota acima).

Após importar cada workflow com Telegram, **substituir `<TELEGRAM_CHAT_ID>`** pelo valor real
(disponível em `docs/credenciais.md` → seção Telegram).

### 3. Vincular credenciais

Em cada workflow importado, abrir os nós HTTP Request e Telegram e selecionar as credenciais criadas no passo 1.

### 4. Vincular o error workflow (02 → 03)

No workflow **02 · Cold — Callback dbt → Telegram**: abrir **Settings → Error Workflow**
e selecionar o workflow **03 · Cold — Erro** (o id muda a cada reimportação, por isso não
vai fixo no JSON). Isso garante que falhas não tratadas no 02 (ex.: timeout do dbt) disparem
o nó `Error Trigger` do 03 e mandem um alerta no Telegram.

### 5. Ativar os workflows

Ativar todos os 7 workflows. Para os que têm webhook (02, 03, 05), fazer ciclo
**deactivate → activate** para registrar os endpoints.

### 6. Verificar os webhooks

Os workflows 02, 03 e 05 usam URLs de webhook que o Hop chama ao final da extração.
Confirmar que as variáveis no Dokploy (`HOP_WEBHOOK_FINISHED_URL`, `HOP_WEBHOOK_ERROR_URL`,
`HOP_HOT_WEBHOOK_URL`) apontam para `https://<N8N_WEBHOOK_HOST>/webhook/<path>`.
