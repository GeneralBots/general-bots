# General Bots — Plano de Execução no Windows

## Pré-requisitos

- Windows 10/11 (x64)
- Visual Studio Build Tools (com C++ workload) ou Visual Studio
- Rust toolchain (`rustup` com `stable-x86_64-pc-windows-msvc`)
- Git para Windows

---

## 1. Dependências de Build

### 1.1 PostgreSQL (libpq.lib para Diesel ORM)

O BotServer usa Diesel com backend Postgres. No Windows, o linker precisa de `libpq.lib`.

```powershell
# Baixar binários do PostgreSQL (não precisa instalar o serviço)
Invoke-WebRequest -Uri "https://get.enterprisedb.com/postgresql/postgresql-17.4-1-windows-x64-binaries.zip" -OutFile "$env:TEMP\pgsql.zip" -UseBasicParsing

# Extrair para C:\pgsql
Expand-Archive -Path "$env:TEMP\pgsql.zip" -DestinationPath "C:\pgsql" -Force

# Configurar variável de ambiente permanente
[System.Environment]::SetEnvironmentVariable("PQ_LIB_DIR", "C:\pgsql\pgsql\lib", "User")
$env:PQ_LIB_DIR = "C:\pgsql\pgsql\lib"
$env:PATH = "C:\pgsql\pgsql\bin;$env:PATH"
```

Ou simplesmente execute:
```powershell
.\DEPENDENCIES.ps1
```

### 1.2 sccache (opcional)

O `.cargo/config.toml` referencia `sccache`. Se não estiver instalado, comente a linha:
```toml
# [build]
# rustc-wrapper = "sccache"
```

---

## 2. Compilação

```powershell
# Garantir que PQ_LIB_DIR está configurado
$env:PQ_LIB_DIR = "C:\pgsql\pgsql\lib"

# Build do botserver
cargo build -p botserver

# Build do botui (interface desktop Tauri)
cargo build -p botui
```

### Correções de compilação aplicadas

| Arquivo | Problema | Correção |
|---------|----------|----------|
| `bootstrap.rs` | `use std::os::unix::fs::PermissionsExt` | Envolvido com `#[cfg(unix)]` |
| `antivirus.rs` | `error!` macro não importada | Adicionado `use tracing::error` |
| `installer.rs` | `check_root()` só existe no Unix | Adicionado `check_admin()` para Windows com `#[cfg(windows)]` |
| `installer.rs` | `SUDOERS_CONTENT` não usado no Windows | Envolvido com `#[cfg(not(windows))]` |
| `facade.rs` | `make_executable` param `path` não usado | Renomeado para `_path` no Windows |

---

## 3. Compatibilidade de Runtime (3rdparty.toml)

O `3rdparty.toml` agora tem entradas `_windows` para cada componente:

| Componente | Linux | Windows |
|------------|-------|---------|
| `drive` | `minio` (linux-amd64) | `minio.exe` (windows-amd64) |
| `tables` | `postgresql-*-linux-gnu.tar.gz` | `postgresql-*-windows-x64-binaries.zip` |
| `cache` | `valkey-*-jammy-x86_64.tar.gz` | `memurai-developer.msi` |
| `llm` | `llama-*-ubuntu-x64.zip` | `llama-*-win-cpu-x64.zip` (ou CUDA/Vulkan) |
| `email` | `stalwart-mail-*-linux.tar.gz` | `stalwart-mail-*-windows.zip` |
| `proxy` | `caddy_*_linux_amd64.tar.gz` | `caddy_*_windows_amd64.zip` |
| `directory` | `zitadel-linux-amd64.tar.gz` | `zitadel-windows-amd64.zip` |
| `alm` | `forgejo-*-linux-amd64` | `forgejo-*-windows-amd64.exe` |
| `alm_ci` | `forgejo-runner-*-linux-amd64` | `forgejo-runner-*-windows-amd64.exe` |
| `dns` | `coredns_*_linux_amd64.tgz` | `coredns_*_windows_amd64.tgz` |
| `meet` | `livekit_*_linux_amd64.tar.gz` | `livekit_*_windows_amd64.zip` |
| `table_editor` | `nocodb-linux-x64` | `nocodb-win-x64.exe` |
| `vector_db` | `qdrant-*-linux-gnu.tar.gz` | `qdrant-*-windows-msvc.zip` |
| `timeseries_db` | `influxdb2-*-linux-amd64.tar.gz` | `influxdb2-*-windows-amd64.zip` |
| `vault` | `vault_*_linux_amd64.zip` | `vault_*_windows_amd64.zip` |
| `observability` | `vector-*-linux-gnu.tar.gz` | `vector-*-windows-msvc.zip` |

A seleção é automática via `get_component_url()` em `installer.rs` que busca `{name}_windows` primeiro.

---

## 4. Adaptações de Código para Windows

### 4.1 Execução de Comandos Shell

| Contexto | Linux | Windows |
|----------|-------|---------|
| `run_commands_with_password()` | `bash -c "{cmd}"` | `powershell -NoProfile -Command "{cmd}"` |
| `start()` (spawnar processos) | `sh -c "{exec_cmd}"` | `powershell -NoProfile -Command "{exec_cmd}"` |
| `safe_sh_command()` | `sh -c` | `powershell -NoProfile -Command` |

### 4.2 Gerenciamento de Processos

| Ação | Linux | Windows |
|------|-------|---------|
| Matar processos | `pkill -9 -f {name}` | `taskkill /F /IM {name}*` |
| Verificar processo | `pgrep -f {name}` | `Get-Process \| Where-Object { $_.ProcessName -like '*{name}*' }` |

### 4.3 Health Checks (fallback quando curl não está disponível)

| Check | Linux | Windows |
|-------|-------|---------|
| Porta aberta | `nc -z -w 1 127.0.0.1 {port}` | `(Test-NetConnection -ComputerName 127.0.0.1 -Port {port}).TcpTestSucceeded` |

### 4.4 Extração de Arquivos

| Formato | Linux | Windows |
|---------|-------|---------|
| `.zip` | `unzip -o -q {file}` | `Expand-Archive -Path '{file}' -DestinationPath '{dest}' -Force` |
| `.tar.gz` | `tar -xzf {file}` | `tar -xzf {file}` (Windows 10+ tem tar nativo) |

---

## 5. Execução

### 5.1 Modo CLI (gerenciar componentes)
```powershell
$env:PQ_LIB_DIR = "C:\pgsql\pgsql\lib"
$env:PATH = "C:\pgsql\pgsql\bin;$env:PATH"

# Instalar um componente específico
.\target\debug\botserver.exe install vault

# Listar componentes
.\target\debug\botserver.exe list

# Iniciar componentes
.\target\debug\botserver.exe start

# Ver status
.\target\debug\botserver.exe status
```

### 5.2 Modo Servidor (bootstrap completo + HTTP)
```powershell
$env:PQ_LIB_DIR = "C:\pgsql\pgsql\lib"
$env:PATH = "C:\pgsql\pgsql\bin;$env:PATH"

# Executa bootstrap (baixa/instala todos os componentes) + inicia servidor HTTP
.\target\debug\botserver.exe
```

O bootstrap automático:
1. Baixa e instala Vault, PostgreSQL, Valkey, MinIO, Zitadel, LLM, etc.
2. Gera certificados TLS
3. Inicializa o banco de dados
4. Inicia o servidor HTTP na porta **5858**

Acesse: **http://localhost:5858**

### 5.3 Via restart.ps1
```powershell
.\restart.ps1
```

---

## 6. Detecção Automática de GPU (LLM)

O sistema detecta automaticamente:
- **CUDA 13.x** → `llama-*-win-cuda-13.1-x64.zip`
- **CUDA 12.x** → `llama-*-win-cuda-12.4-x64.zip`
- **Vulkan SDK** → `llama-*-win-vulkan-x64.zip`
- **CPU only** → `llama-*-win-cpu-x64.zip`
- **ARM64** → `llama-*-win-cpu-arm64.zip`

---

## 7. Estrutura de Diretórios

```
botserver-stack/
├── bin/           # Binários dos componentes
│   ├── vault/
│   ├── tables/    # PostgreSQL
│   ├── cache/     # Valkey/Memurai
│   ├── drive/     # MinIO
│   ├── directory/ # Zitadel
│   ├── llm/       # llama.cpp
│   └── ...
├── conf/          # Configurações
│   ├── vault/
│   ├── system/certificates/
│   └── ...
├── data/          # Dados persistentes
│   ├── vault/
│   ├── tables/pgdata/
│   └── ...
└── logs/          # Logs de cada componente
    ├── vault/
    ├── tables/
    └── ...

botserver-installers/  # Cache de downloads (reutilizado)
```

---

## 8. Troubleshooting

### Erro: `LNK1181: libpq.lib não encontrado`
```powershell
$env:PQ_LIB_DIR = "C:\pgsql\pgsql\lib"
# Ou execute .\DEPENDENCIES.ps1
```

### Erro: `sccache não encontrado`
Comente no `.cargo/config.toml`:
```toml
# [build]
# rustc-wrapper = "sccache"
```

### Erro: `Path traversal detected`
Limpe o cache e recompile:
```powershell
Remove-Item -Path ".\botserver-stack" -Recurse -Force
Remove-Item -Path ".\botserver-installers" -Recurse -Force
cargo clean -p botserver
cargo build -p botserver
```

### Componentes baixam versão Linux
Recompile o botserver para que o `3rdparty.toml` embutido seja atualizado:
```powershell
cargo clean -p botserver
cargo build -p botserver
```
