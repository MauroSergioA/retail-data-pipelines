# Pipeline: max_empresa

## Visão geral

| Atributo | Valor |
|----------|-------|
| Origem | `CONSINCO.MAX_EMPRESA` (Oracle) |
| Destino | `raw.max_empresa` (PostgreSQL) |
| Pipeline Hop | `extract/consinco/max_empresa.hpl` |
| Frequência | Diária (carga completa) |
| Estratégia | TRUNCATE + INSERT |
| Linhas (mai/2026) | 12 (todas as lojas, ativas e inativas) |

## O que extrai

Cadastro completo de empresas e lojas da rede Superque. Inclui dados cadastrais,
endereço, metas operacionais e os CGOs (Códigos Gerais de Operação) de cada loja —
necessários para filtrar movimentações de estoque no futuro.

A extração traz **todas as lojas**, incluindo as inativas (3 e 4). O filtro de
loja ativa é responsabilidade dos modelos dbt e dos relatórios Power BI.

## Colunas extraídas

| Coluna Oracle | Coluna raw | Tipo | Descrição |
|---------------|-----------|------|-----------|
| `NROEMPRESA` | `nroempresa` | INTEGER | Código único da loja — chave primária |
| `NRODIVISAO` | `nrodivisao` | INTEGER | Divisão comercial |
| `RAZAOSOCIAL` | `razaosocial` | TEXT | Razão social |
| `ENDERECO` | `endereco` | TEXT | Logradouro |
| `BAIRRO` | `bairro` | TEXT | Bairro |
| `CEP` | `cep` | TEXT | CEP |
| `CIDADE` | `cidade` | TEXT | Cidade |
| `UF` | `uf` | TEXT | Estado |
| `NROCGC` | `nrocgc` | NUMERIC | CNPJ (parte numérica) |
| `DIGCGC` | `digcgc` | NUMERIC | Dígitos verificadores do CNPJ |
| `INSCRICAOESTADUAL` | `inscricaoestadual` | TEXT | Inscrição estadual |
| `NROMETRO2LOJA` | `nrometro2loja` | NUMERIC | Área da loja em m² |
| `SEQPESSOAEMP` | `seqpessoaemp` | NUMERIC | Sequencial de pessoa jurídica |
| `NROSEGMENTOPRINC` | `nrosegmentoprinc` | NUMERIC | Segmento principal da loja |
| `INDABERTSABADO` | `indabertsabado` | TEXT | Abre aos sábados (S/N) |
| `INDABERTDOMINGO` | `indabertdomingo` | TEXT | Abre aos domingos (S/N) |
| `METAGERMARGEMLUCRO` | `metagermargemlucro` | NUMERIC | Meta de margem de lucro |
| `METAGERDIAESTQ` | `metagerdiaestq` | NUMERIC | Meta de dias de estoque |
| `STATUS` | `status` | TEXT | Status da loja: A = ativa, I = inativa |
| `DTAFECHAFISCAL` | `dtafechafiscal` | DATE | Data de fechamento fiscal |
| `DTAINICIOMOVESTOQUE` | `dtainiciomovestoque` | DATE | Início do controle de estoque |
| `NRONSUNF` | `nronsunf` | INTEGER | Último NSU de NF |
| `CGO*` (14 colunas) | `cgo_*` | INTEGER | Códigos de operação por tipo de movimento |
| — | `_loaded_at` | TIMESTAMP | Timestamp de início da extração (Hop SystemInfo) |

## Modelo dbt downstream

```
raw.max_empresa
    └── staging.stg_max_empresa   (view — cast + rename + snake_case)
            └── dw.dim_empresa_info  (table — desc_loja, CNPJ formatado, endereço completo)
```

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-22 | Pipeline criado, 12 linhas carregadas |
| 2026-05-27 | Coluna `_loaded_at` adicionada via SystemInfo |
