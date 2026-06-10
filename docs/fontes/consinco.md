# Fonte: Consinco (Oracle)

## Visão geral

Consinco é o ERP principal da rede Superque. É a fonte mais crítica do projeto —
contém vendas, estoque, produtos, fornecedores e cadastros operacionais.

| Atributo | Valor |
|----------|-------|
| Tipo | Oracle Database (JDBC) |
| Conexão Hop | `oracle-consinco` |
| Schema Oracle | `CONSINCO` |
| Dados disponíveis desde | 01/08/2022 |

A string de conexão Oracle está em `extract/config/` (gitignored).

---

## Tabelas extraídas

### Dimensões (carga completa diária)

| Tabela Oracle | Tabela raw | Pipeline | Descrição |
|--------------|-----------|---------|-----------|
| `MAX_EMPRESA` | `raw.max_empresa` | `max_empresa.hpl` | Cadastro de lojas |
| `MAP_PRODUTO` | `raw.map_produto` | `map_produto.hpl` | Cadastro de produtos |
| `MAP_FAMILIA` | `raw.map_familia` | `map_familia.hpl` | Famílias de produtos |
| `MAP_MARCA` | `raw.map_marca` | `map_marca.hpl` | Marcas |
| `MAF_FORNECDIVISAO` | `raw.maf_fornecdivisao` | `maf_fornecdivisao.hpl` | Fornecedores por divisão |
| `MRL_PRODUTOEMPRESA` | `raw.mrl_produtoempresa` | `mrl_produtoempresa.hpl` | Produto × loja (estoque, custo) |
| `GE_PESSOA` | `raw.ge_pessoa` | `ge_pessoa.hpl` | Cadastro de pessoas |
| `MAP_FAMEMBALAGEM` | `raw.map_famembalagem` | `map_famembalagem.hpl` | Embalagens por família |
| `MAP_FAMFORNEC` | `raw.map_famfornec` | `map_famfornec.hpl` | Família × fornecedor |
| `MAP_PRODCODIGO` | `raw.map_prodcodigo` | `map_prodcodigo.hpl` | Códigos alternativos de produto |
| `MAPV_NCM` | `raw.mapv_ncm` | `mapv_ncm.hpl` | NCM fiscal |
| `MAX_CODGERALOPER` | `raw.max_codgeraloper` | `max_codgeraloper.hpl` | Códigos de operação |
| `MAX_COMPRADOR` | `raw.max_comprador` | `max_comprador.hpl` | Compradores |
| `MAX_PARAMETRO` | `raw.max_parametro` | `max_parametro.hpl` | Parâmetros do sistema |
| `MAD_SEGMENTO` | `raw.mad_segmento` | `mad_segmento.hpl` | Segmentos |
| `MRL_FORMAPAGTO` | `raw.mrl_formapagto` | `mrl_formapagto.hpl` | Formas de pagamento |
| `MRL_LOCAL` | `raw.mrl_local` | `mrl_local.hpl` | Locais de estoque |
| `PDV_OPERADOR` | `raw.pdv_operador` | `pdv_operador.hpl` | Operadores de caixa |
| `TB_USUARIO` | `raw.tb_usuario` | `tb_usuario.hpl` | Usuários do sistema |
| `VW_PDV` | `raw.vw_pdv` | `vw_pdv.hpl` | PDVs cadastrados |
| `ETLV_CATEGORIA` | `raw.etlv_categoria` | `etlv_categoria.hpl` | Categorias ETL |
| `MADV_SITUACAOPED` | `raw.madv_situacaoped` | `madv_situacaoped.hpl` | Situações de pedido |
| `MADV_TIPPEDIDO` | `raw.madv_tippedido` | `madv_tippedido.hpl` | Tipos de pedido |
| `MADV_ORIGEMPEDIDO` | `raw.madv_origempedido` | `madv_origempedido.hpl` | Origens de pedido |

### Fatos (carga incremental rolling)

| Tabela Oracle | Tabela raw | Pipeline | Estratégia |
|--------------|-----------|---------|-----------|
| `MAXV_ABCDISTRIBBASE` + joins | `raw.maxv_abcdistribbase` | `maxv_abcdistribbase.hpl` | Hot 4×/dia (hoje) + Cold 1×/madrugada (D-5) |

---

## Padrão de extração

Todos os pipelines seguem o mesmo fluxo de 3 transforms:

```
src_<tabela>         →    sys_loaded_at    →    raw_<tabela>
(TableInput Oracle)       (SystemInfo)          (TableOutput PG)
```

O `sys_loaded_at` injeta a coluna `_loaded_at` com o timestamp de início da execução
(`system date (fixed)`) — o mesmo valor para todas as linhas do run.

---

## Operações de venda válidas

Regra de negócio crítica usada em todos os modelos de venda:

```sql
CODGERALOPER IN (800, 810, 820, 828, 202)
```

`800, 810, 820, 828` = vendas. `202` = devoluções.

---

## Changelog

| Data | Alteração |
|------|-----------|
| 2026-05-28 | Primeira extração: max_empresa, map_produto, map_familia, map_marca, maf_fornecdivisao, mrl_produtoempresa |
| 2026-05-28 | Pipeline incremental fato_venda (maxv_abcdistribbase) implementado e validado |
| 2026-05-28 | 15+ pipelines de dimensão adicionados |
