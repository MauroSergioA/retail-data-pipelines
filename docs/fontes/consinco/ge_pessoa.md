# Pipeline: ge_pessoa

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.GE_PESSOA` (Oracle) |
| Destino | `raw.ge_pessoa` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/ge_pessoa.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |

## O que extrai

Cadastro geral de pessoas físicas e jurídicas do Consinco. Funciona como
tabela-base de identificação para fornecedores, compradores, operadores e
usuários — todas essas entidades possuem um `seqpessoa` que referencia
este cadastro.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `SEQPESSOA` | `seqpessoa` | INTEGER | Código sequencial — chave primária |
| `NOMERAZAO` | `nomerazao` | TEXT | Nome ou razão social |
| `FANTASIA` | `fantasia` | TEXT | Nome fantasia |
| `STATUS` | `status` | TEXT | Status do cadastro |
| `FISICAJURIDICA` | `fisicajuridica` | TEXT | Tipo: F = física, J = jurídica |
| `LOGRADOURO` | `logradouro` | TEXT | Logradouro |
| `NROLOGRADOURO` | `nrologradouro` | TEXT | Número do logradouro |
| `BAIRRO` | `bairro` | TEXT | Bairro |
| `CIDADE` | `cidade` | TEXT | Cidade |
| `CEP` | `cep` | TEXT | CEP |
| `UF` | `uf` | TEXT | Estado |
| `PAIS` | `pais` | TEXT | País |
| `NROCGCCPF` | `nrocgccpf` | TEXT | CNPJ ou CPF (sem dígito verificador) |
| `DIGCGCCPF` | `digcgccpf` | TEXT | Dígito verificador do CNPJ/CPF |
| `INSCRICAORG` | `inscricaorg` | TEXT | Inscrição estadual |
| `EMAIL` | `email` | TEXT | E-mail |
| `DTAINCLUSAO` | `dtainclusao` | DATE | Data de inclusão no cadastro |
| `INDCONTRIBICMS` | `indcontribicms` | TEXT | Contribuinte de ICMS: S/N |
| `INDPRODRURAL` | `indprodrural` | TEXT | Produtor rural: S/N |
| `INDCONTRIBIPI` | `indcontribipi` | TEXT | Contribuinte de IPI: S/N |
| `CNAE` | `cnae` | TEXT | Código CNAE da atividade |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.ge_pessoa
    └── (futuro: referenciada em dim_fornecedor, dim_operador via seqpessoa)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-26 | Pipeline criado |
