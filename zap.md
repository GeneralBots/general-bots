# WhatsApp - Bot Salesianos
respeitar AGENTS.md
## Status: Operacional

| Campo | Valor |
|-------|-------|
| Bot ID | `32c579e5-609b-4a07-8599-4e0fccc4d764` |
| Phone | +15558293147 |
| Phone ID | 323250907549153 |
| Business ID | 1261667644771701 |

---

## Comandos

- `/clear` - Limpa histórico da conversa

---

## Streaming

1. Mensagens sem lista: enviar a cada 3 parágrafos
2. Mensagens com lista: **ISOLAR como mensagem única** (sem texto antes ou depois)
3. Limite máximo: 4000 caracteres por mensagem

### Exemplo de Agrupamento Correto

**Resposta completa do bot:**
```
Olá! 😊

Infelizmente, não tenho a informação específica sobre o horário de funcionamento da Escola Salesiana no momento.

Para obter essa informação, você pode:
1. *Entrar em contato com a secretaria* - Posso te ajudar a enviar uma mensagem perguntando sobre os horários
2. *Agendar uma visita* - Assim você conhece a escola pessoalmente e obtém todas as informações necessárias

Gostaria que eu te ajudasse com alguma dessas opções? Se quiser entrar em contato com a secretaria, preciso apenas de:
- Seu nome
- Telefone
- Email
- Sua pergunta sobre os horários

Ou, se preferir, posso agendar uma visita para você conhecer a escola! 🏫

O que prefere?
```

**Deve ser enviado como 5 mensagens separadas:**

**Mensagem 1:**
```
Olá! 😊

Infelizmente, não tenho a informação específica sobre o horário de funcionamento da Escola Salesiana no momento.

Para obter essa informação, você pode:
```

**Mensagem 2 (LISTA ISOLADA):**
```
1. *Entrar em contato com a secretaria* - Posso te ajudar a enviar uma mensagem perguntando sobre os horários
2. *Agendar uma visita* - Assim você conhece a escola pessoalmente e obtém todas as informações necessárias
```

**Mensagem 3:**
```
Gostaria que eu te ajudasse com alguma dessas opções? Se quiser entrar em contato com a secretaria, preciso apenas de:
```

**Mensagem 4 (LISTA ISOLADA):**
```
- Seu nome
- Telefone
- Email
- Sua pergunta sobre os horários
```

**Mensagem 5:**
```
Ou, se preferir, posso agendar uma visita para você conhecer a escola! 🏫

O que prefere?
```

**Regras:**
- ✅ Cada lista = **1 mensagem ISOLADA** (nunca misturar com texto)
- ✅ Texto antes da lista = mensagem separada
- ✅ Texto depois da lista = mensagem separada
- ✅ Listas nunca são quebradas no meio

---

## Testar Webhook (Simular Callback)

Script de teste em `/tmp/test_whatsapp.sh`:

```bash
#!/bin/bash
# Testa o webhook do WhatsApp simulando uma mensagem

BOT_ID="32c579e5-609b-4a07-8599-4e0fccc4d764"
FROM="5521972102162"  # Número de teste

curl -X POST "http://localhost:8080/webhook/whatsapp/${BOT_ID}" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "whatsapp_business_account",
    "entry": [{
      "id": "1261667644771701",
      "changes": [{
        "field": "messages",
        "value": {
          "messaging_product": "whatsapp",
          "metadata": {
            "display_phone_number": "15558293147",
            "phone_number_id": "323250907549153"
          },
          "contacts": [{
            "wa_id": "'${FROM}'",
            "profile": { "name": "Teste Usuario" }
          }],
          "messages": [{
            "id": "test_msg_'$(date +%s)'",
            "from": "'${FROM}'",
            "timestamp": "'$(date +%s)'",
            "type": "text",
            "text": { "body": "Olá, como posso ajudar?" }
          }]
        }
      }]
    }]
  }'
```

Executar teste:
```bash
bash /tmp/test_whatsapp.sh
```

---

## Testar Comando /clear

```bash
BOT_ID="32c579e5-609b-4a07-8599-4e0fccc4d764"
FROM="5521972102162"

curl -X POST "http://localhost:8080/webhook/whatsapp/${BOT_ID}" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "whatsapp_business_account",
    "entry": [{
      "id": "1261667644771701",
      "changes": [{
        "field": "messages",
        "value": {
          "messaging_product": "whatsapp",
          "metadata": {
            "display_phone_number": "15558293147",
            "phone_number_id": "323250907549153"
          },
          "contacts": [{
            "wa_id": "'${FROM}'",
            "profile": { "name": "Teste Usuario" }
          }],
          "messages": [{
            "id": "test_clear_'$(date +%s)'",
            "from": "'${FROM}'",
            "timestamp": "'$(date +%s)'",
            "type": "text",
            "text": { "body": "/clear" }
          }]
        }
      }]
    }]
  }'
```

---

## Debug

```bash
# Verificar servidor
curl http://localhost:8080/health

# Monitorar logs
tail -f botserver.log | grep -iE "(whatsapp|Embedding)"

# Verificar sessões ativas (requer acesso ao banco)
# SELECT * FROM user_sessions WHERE bot_id = '32c579e5-609b-4a07-8599-4e0fccc4d764';
```

---

## Arquivos Relacionados

- Config: `/opt/gbo/data/salesianos.gbai/salesianos.gbot/config.csv`
- Handler: `botserver/src/whatsapp/mod.rs`
- Adapter: `botserver/src/core/bot/channels/whatsapp.rs`
- Cache: `botserver/src/llm/cache.rs`

---

## Pendências

1. **Implementar suporte a `/webhook/whatsapp/default`** (ver TODO abaixo)
2. Configurar webhook na Meta Business Suite para produção
3. Configurar SSL/TLS no servidor de produção

---

## 📋 TODO: Default Bot Routing

### Objetivo
Permitir que a URL `/webhook/whatsapp/default` funcione como roteador dinâmico de bots baseado em comandos de usuário.

### Comportamento Atual
- ✅ `/webhook/whatsapp/{uuid}` → Rota direta para bot específico
- ❌ `/webhook/whatsapp/default` → **FALHA** (espera UUID, não aceita "default")

### Comportamento Desejado
1. `/webhook/whatsapp/default` → Rota para o bot default (`/opt/gbo/data/default.gbai/default.gbot`)
2. Quando usuário digita um `whatsapp-id` (ex: "cristo", "salesianos"):
   - Sistema busca bot com essa propriedade no `config.csv`
   - Mapeia `phone_number` → `bot_id` na sessão/cache
   - Troca de bot para aquela sessão
3. Mensagens subsequentes daquele `phone_number` são roteadas para o bot mapeado
4. Se usuário digitar outro `whatsapp-id`, encerra sessão anterior e abre nova para o novo bot

### Arquivos a Modificar

#### 1. `botserver/src/whatsapp/mod.rs`
- **Linha ~178**: Modificar `verify_webhook` e `handle_webhook`
  - Mudar `Path(bot_id): Path<Uuid>` → `Path(bot_id): Path<String>`
  - Adicionar parsing: `"default"` → buscar UUID do bot default
  - Manter parsing UUID para compatibilidade

#### 2. `botserver/src/whatsapp/mod.rs`
- **Nova função**: `resolve_bot_id(bot_id_str: &str, state: &AppState) -> Result<Uuid, Error>`
  - Se `"default"` → retorna UUID do bot default via `get_default_bot()`
  - Se UUID válido → retorna UUID
  - Caso contrário → erro

#### 3. `botserver/src/whatsapp/mod.rs`
- **Nova função**: `check_whatsapp_id_routing(message_text: &str, state: &AppState) -> Option<Uuid>`
  - Verifica se texto é um comando de troca de bot
  - Busca em todos os bots por `whatsapp-id` no `config.csv`
  - Retorna bot_id se encontrar match

#### 4. `botserver/src/whatsapp/mod.rs`
- **Modificar** `process_incoming_message`
  - Antes de processar, verificar se mensagem é comando de roteamento
  - Se for, atualizar mapeamento `phone` → `bot_id` no cache
  - Se não for, usar mapeamento existente do cache

### Bots com whatsapp-id Configurado
- ✅ **cristo.gbot**: `whatsapp-id,cristo`
- ❓ **salesianos.gbot**: verificar se tem whatsapp-id
- ✅ **default.gbot**: não tem whatsapp-id (é o roteador)

### Implementação em Passos

**Passo 1**: Modificar handlers para aceitar "default"
```rust
// Antes
Path(bot_id): Path<Uuid>

// Depois
Path(bot_id_str): Path<String>
let bot_id = resolve_bot_id(&bot_id_str, &state)?;
```

**Passo 2**: Implementar `resolve_bot_id`
- Buscar `get_default_bot()` quando `bot_id_str == "default"`
- Parse UUID caso contrário

**Passo 3**: Implementar roteamento dinâmico
- Verificar cache: `phone_number` → `bot_id`
- Se não existir, usar bot_id do webhook
- Se mensagem for comando (whatsapp-id), atualizar cache

**Passo 4**: Testar
```bash
# Teste 1: URL com default
curl -X POST "http://localhost:8080/webhook/whatsapp/default" ...

# Teste 2: URL com UUID (deve continuar funcionando)
curl -X POST "http://localhost:8080/webhook/whatsapp/32c579e5-609b-4a07-8599-4e0fccc4d764" ...

# Teste 3: Roteamento por comando
# Enviar mensagem "cristo" → deve rotear para bot cristo
# Enviar mensagem "salesianos" → deve trocar para bot salesianos
```

### URLs de Teste
- Localtunnel: `https://bright-bananas-deny.loca.lt/webhook/whatsapp/default`
- Local: `http://localhost:8080/webhook/whatsapp/default`
