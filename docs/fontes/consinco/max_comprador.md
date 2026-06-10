# Pipeline: max_comprador

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAX_COMPRADOR` (Oracle) |
| Destino | `raw.max_comprador` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/max_comprador.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro de compradores da rede. Vinculado a `ge_pessoa` via `seqpessoa`
para obter dados cadastrais completos (nome, CPF, contato).

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQCOMPRADOR` | `seqcomprador` | INTEGER | Código sequencial — chave primária |
| `COMPRADOR` | `comprador` | TEXT | Nome do comprador |
| `APELIDO` | `apelido` | TEXT | Apelido do comprador |
| `ASSINATELETRONICA` | `assinateletronica` | TEXT | Assinatura eletrônica |
| `STATUS` | `status` | TEXT | Status do comprador |
| `SEQPESSOA` | `seqpessoa` | INTEGER | Código da pessoa (FK → ge_pessoa) |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
