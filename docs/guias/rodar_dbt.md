# Como rodar o dbt

## Pré-requisito

O ambiente virtual do dbt está em `C:\venv\dbt\`. Ele precisa estar no PATH antes de qualquer
comando dbt. Execute isso no início de cada sessão PowerShell:

```powershell
$env:PATH = "C:\venv\dbt\Scripts;$env:PATH"
```

## Diretório de trabalho

O `dbt_project.yml` está em `transform\`, não na raiz do repositório.
Sempre entre na subpasta antes de rodar:

```powershell
cd C:\Projetos\retail-data-pipelines\transform
```

Ou, de qualquer lugar:

```powershell
cd C:\Projetos\retail-data-pipelines\transform; dbt run
```

## Comandos do dia a dia

### Rodar todos os modelos

```powershell
dbt run
```

### Rodar um modelo específico

```powershell
dbt run --select fato_venda
dbt run --select dim_empresa_info
```

### Rodar um modelo e todos que dependem dele (downstream)

```powershell
dbt run --select fato_venda+
```

### Rodar testes

```powershell
dbt test                          # todos os modelos
dbt test --select fato_venda      # modelo específico
```

### Ver linhagem no terminal

```powershell
dbt ls --select fato_venda        # lista dependências
```

### Compilar sem executar (debug de SQL gerado)

```powershell
dbt compile --select fato_venda
```

O SQL compilado fica em `transform\target\compiled\`.

## Primeira execução de um modelo incremental

Na primeira vez que um modelo incremental é rodado, o dbt cria a tabela do zero
(equivalente a um `--full-refresh`). Não é necessário nenhum flag especial.

```powershell
dbt run --select fato_venda   # cria a tabela na primeira vez
dbt run --select fato_venda   # incremental a partir da segunda
```

## Forçar reconstrução completa (full-refresh)

Use apenas quando necessário — apaga e recria a tabela inteira:

```powershell
dbt run --select fato_venda --full-refresh
```

**Não use** no `fato_venda` em produção a menos que queira perder o histórico acumulado.
Para reprocessar um período específico, use a carga histórica via Hop.

## Verificar conexão com o banco

```powershell
dbt debug
```

O `profiles.yml` está em `transform\profiles.yml` (gitignored — não está no repositório).
