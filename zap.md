# WhatsApp - Bot Salesianos

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

1. ~~Filtrar caracteres Markdown inválidos no WhatsApp (###, **, etc)~~ ✅ **Concluído em 2025-03-08**
2. Configurar webhook na Meta Business Suite para produção
3. Configurar SSL/TLS no servidor de produção

---

## Histórico de Correções

### 2025-03-08: Sanitização de Markdown para WhatsApp

**Problema**: O WhatsApp não suporta Markdown completo (headers, links formatados, etc), causando exibição incorreta de mensagens.

**Solução**: Adicionada função `sanitize_for_whatsapp()` em `botserver/src/core/bot/channels/whatsapp.rs` que:
- Remove headers Markdown (###, ##, #)
- Converte links `[texto](url)` para `texto: url`
- Remove sintaxe de imagem `![alt](url)`
- Converte checkboxes `[ ]` e `[x]` para bullets
- Remove horizontal rules (`---`, `***`)
- Remove tags HTML
- Limpa linhas em branco excessivas

**Resultado**: Mensagens agora são exibidas corretamente no WhatsApp.

### 2025-03-08: Cache Semântico

**Problema**: O cache semântico estava enviando todo o histórico de conversa (10000+ chars) para o embedding, causando falsos positivos.

**Solução**: Modificado `botserver/src/llm/cache.rs` para extrair apenas a última pergunta do usuário do array de mensagens.

```rust
// Antes (problemático):
let combined_context = format!("{}\n{}", prompt, actual_messages);

// Depois (corrigido):
let latest_user_question = msgs.iter().rev()
    .find_map(|msg| {
        if msg.get("role") == Some("user") {
            msg.get("content").and_then(|c| c.as_str())
        } else { None }
    });
```

**Resultado**: Embedding agora usa apenas ~52 chars (pergunta do usuário) em vez de 10000+ chars.

### 2025-03-08: Correção de Streaming para Listas

**Problema**: Listas numeradas estavam sendo quebradas em múltiplas mensagens durante o streaming, mesmo quando cabiam em uma única mensagem de 4000 caracteres.

**Causa**: A detecção de lista era feita APÓS decidir fazer flush baseado em 3 parágrafos. Quando o streaming enviava chunks parciais, o código não detectava que uma lista estava começando.

**Solução**: Melhorada a lógica de detecção em `botserver/src/whatsapp/mod.rs`:

1. **Detecção mais precisa de listas numeradas**: Agora requer padrão `N.` ou `N)` seguido de espaço (ex: "1. Item", "10) Item")
2. **Detecção de início de lista**: Nova função `looks_like_list_start()` detecta quando o buffer parece estar começando uma lista (header terminando em `:` ou número no início)
3. **Logs detalhados**: Adicionado logging para debug de streaming

**Resultado**: Listas agora são acumuladas corretamente e enviadas em uma única mensagem quando possível.

### 2025-03-08: Detecção de Fim de Lista no Streaming

**Problema**: Listas estavam sendo enviadas como mensagens únicas apenas quando o streaming terminava (`is_final`), mesmo que a lista já tivesse terminado. Isso causava atrasos na entrega de mensagens quando havia conteúdo após a lista.

**Causa**: Uma vez que uma lista era detectada (`has_list = true`), o código esperava até `is_final` ou `buffer.len() >= MAX_WHATSAPP_LENGTH` para fazer flush. Não havia detecção de quando a lista terminava.

**Solução**: 
- Adicionada função `looks_like_list_end()` em `botserver/src/whatsapp/mod.rs` que detecta quando uma lista terminou (verifica se as últimas 2 linhas não-brancas não são itens de lista)
- Modificada a lógica de streaming para fazer flush quando `list_ended = true`
- Adicionados testes unitários para validar o novo comportamento

**Resultado**: Listas agora são enviadas assim que terminam, sem esperar o streaming completar. Conteúdo após a lista é entregue prontamente, melhorando a experiência do usuário.

### 2025-03-08: Isolamento de Listas como Mensagens Únicas

**Problema**: Listas estavam sendo enviadas misturadas com texto antes e depois, em vez de serem isoladas como mensagens únicas. Por exemplo, "Texto introdutório\n1. Item\n2. Item\nTexto final" era enviado como uma única mensagem, quando deveria ser 3 mensagens separadas.

**Causa**: A lógica de streaming acumulava todo o buffer quando detectava uma lista, sem separar o texto antes/depois da lista. O buffer era enviado como um bloco único.

**Solução**: Implementado isolamento de listas em `botserver/src/whatsapp/mod.rs`:
- Adicionada função `split_text_before_list()` para separar texto antes da lista
- Adicionada função `split_list_from_text()` para separar lista do texto depois
- Modificada lógica de streaming para:
  1. Detectar quando lista termina (`list_ended = true`)
  2. Separar texto ANTES da lista e enviar como mensagem
  3. Separar lista e enviar como mensagem ISOLADA
  4. Manter texto DEPOIS no buffer para próxima mensagem

**Resultado**: Listas agora são enviadas como mensagens ISOLADAS, sem misturar com texto antes ou depois. Cada lista = 1 mensagem separada, melhorando a legibilidade e experiência do usuário no WhatsApp.

### 2025-03-08: Remoção de Blocos de Código JavaScript

**Problema**: Código de programação (JavaScript, C#, etc.) estava vazando nas mensagens do WhatsApp. Exemplos como `var telefoneDigits = new string(args.Phone.Where(char.IsDigit).ToArray());` eram enviados para os usuários, quando deveriam ser removidos.

**Causa**: A função `sanitize_for_whatsapp()` em `botserver/src/core/bot/channels/whatsapp.rs` removia Markdown e HTML, mas não removia blocos de código cercados por crases (backticks).

**Solução**: Adicionados padrões regex à função `sanitize_for_whatsapp()`:
- Remove blocos de código com crases triplas: ```code```
- Remove código inline com crase simples: `code`
- Limpa código de programação antes de enviar para WhatsApp

**Resultado**: Mensagens do WhatsApp agora estão livres de código de programação, exibindo apenas texto legível para o usuário. Código JavaScript, C#, e outras linguagens são automaticamente removidos durante a sanitização.
