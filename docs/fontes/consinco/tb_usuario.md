# Pipeline: tb_usuario

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCOMONITOR.TB_USUARIO` (Oracle — schema monitor) |
| Destino | `raw.tb_usuario` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/tb_usuario.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de usuários do sistema Consinco. Vinculado a `ge_pessoa` via `seqpessoa`.
Extraído do schema `CONSINCOMONITOR` (não do schema principal `CONSINCO`).

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQUSUARIO` | `sequsuario` | INTEGER | Código sequencial — chave primária |
| `NOME` | `nome` | TEXT | Nome completo do usuário |
| `APELIDO` | `apelido` | TEXT | Login/apelido do usuário |
| `NIVEL` | `nivel` | TEXT | Nível de acesso |
| `ATIVO` | `ativo` | TEXT | Usuário ativo: S/N |
| `SEQPESSOA` | `seqpessoa` | INTEGER | Código da pessoa (FK → ge_pessoa) |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
