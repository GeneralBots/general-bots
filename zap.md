# Configuração WhatsApp - Bot Salesianos

## Status Atual

| Campo | Valor | Status |
|-------|-------|--------|
| Phone Number | +15558293147 | ✅ |
| Phone Number ID | 323250907549153 | ✅ Configurado |
| Business Account ID | 1261667644771701 | ✅ Configurado |
| APP ID | 948641861003702 | ✅ |
| Client Token | 84ba0c232681678376c7693ad2252763 | ⚠️ Temporário |
| API Key (Permanent Token) | EAAQdlso6aM8B... (configured) | ✅ Configurado |
| Verify Token | webhook_verify_salesianos_2024 | ✅ Configurado |

---

## 🐛 Problema Identificado (2026-03-06)

**Sintoma**: Mensagens são recebidas mas ignoradas pelo bot (query vazia no KB)

**Diagnóstico**:
- ✅ Webhook está recebendo mensagens corretamente
- ✅ Mensagens estão sendo parseadas (Message ID, Type, From identificados)
- ✅ Sessão está sendo criada no banco
- ❌ **Conteúdo da mensagem está sendo perdido** - KB recebe query vazia

**Logs de evidência**:
```
Processing WhatsApp message from Rodrigo Rodriguez (5521972102162) for bot 32c579e5-609b-4a07-8599-4e0fccc4d764: type=text
Routing WhatsApp message to bot for session 350a9afe-0d4e-4315-84e1-e8
Searching collection 'salesianos_website_salesianos_br' with query:  ← EMPTY!
```

**Próximos passos de debug**:
1. [x] Verificar estrutura do JSON recebido do WhatsApp - EM ANDAMENTO
2. [x] Adicionar log do conteúdo extraído em `extract_message_content()` - FEITO
3. [ ] Verificar se campo `text.body` está presente no webhook payload
4. [ ] Testar manualmente com curl simulando payload do WhatsApp

**Ações tomadas**:
- ✅ Adicionado debug logging em `handle_webhook()` para ver mensagens recebidas
- ✅ Adicionado debug logging em `process_incoming_message()` para ver conteúdo extraído
- ✅ Verificado config.csv - todos os campos WhatsApp estão configurados corretamente
- ⏳ Servidor sendo recompilado com novo logging

**Estrutura atual do webhook**:
- URL: `/webhook/whatsapp/:bot_id`
- O bot_id está sendo passado corretamente na URL
- O problema NÃO é de roteamento - mensagens chegam ao handler correto

---

## Fase 1: Configuração Básica

- [ ] **Obter Permanent Access Token**
  - Acessar [Meta Business Suite](https://business.facebook.com/)
  - Navegar para **WhatsApp** → **API Settings**
  - Gerar token permanente
  - Adicionar ao config.csv: `whatsapp-api-key,<SEU_TOKEN>`

- [ ] **Verificar config.csv atual**
  - Arquivo: `/opt/gbo/data/salesianos.gbai/salesianos.gbot/config.csv`
  - Campos obrigatórios:
    - `whatsapp-phone-number-id` ✅
    - `whatsapp-business-account-id` ✅
    - `whatsapp-api-key` ❌ (pendente)

- [ ] **Configurar webhook na Meta**
  - URL: `https://<seu-dominio>/webhook/whatsapp`
  - Verify Token: `webhook_verify` (ou customizar)
  - Callback URL verificará o token

---

## Fase 2: Configuração do Webhook

- [ ] **Verificar se webhook está acessível externamente**
  - Porta 8080 deve estar acessível
  - Configurar reverse proxy (nginx/traefik) se necessário
  - Configurar SSL/TLS (obrigatório para produção)

- [ ] **Testar verificação do webhook**
  ```bash
  curl "http://localhost:8080/webhook/whatsapp?hub.mode=subscribe&hub.challenge=test&hub.verify_token=webhook_verify"
  ```
  - Deve retornar o challenge

- [ ] **Registrar webhook na Meta**
  - Webhooks → WhatsApp Business Account
  - Subscrever eventos: `messages`, `messaging_postbacks`

---

## Fase 3: Arquitetura Multi-Bot (Melhoria)

> **Problema identificado**: O webhook atual envia todas as mensagens para o primeiro bot ativo

- [ ] **Implementar roteamento por phone_number_id**
  - Criar função `get_bot_id_by_phone_number_id()`
  - Modificar `find_or_create_session()` em `botserver/src/whatsapp/mod.rs`

- [ ] **Considerar estrutura de URL alternativa**
  - Atual: `/webhook/whatsapp`
  - Proposto: `/webhook/whatsapp/{bot_identifier}`

- [ ] **Adicionar tabela de mapeamento** (opcional)
  - `phone_number_id` → `bot_id`
  - Ou usar lookup no config.csv de cada bot

---

## Fase 4: Testes

### Teste de Webhook Local

- [x] **Script de teste criado**: `/tmp/test_whatsapp_webhook.sh`
  - Simula payload do WhatsApp
  - Testa extração de conteúdo
  - Verifica processamento do bot

- [ ] **Teste de envio de mensagem**
  ```bash
  # Via API
  curl -X POST http://localhost:8080/api/whatsapp/send \
    -H "Content-Type: application/json" \
    -d '{"to": "<numero_teste>", "message": "Teste"}'
  ```

- [ ] **Teste de recebimento de mensagem**
  - Enviar mensagem WhatsApp para +15558293147
  - Verificar logs: `tail -f botserver.log | grep whatsapp`
  - **COMANDO DE DEBUG**: `tail -f botserver.log | grep -E "(Extracted content|Processing WhatsApp)"`

- [ ] **Verificar criação de sessão**
  - Conferir se mensagem foi processada pelo bot correto
  - Verificar se não há erros no log

### Comandos Úteis para Debug

```bash
# Ver mensagens WhatsApp em tempo real
tail -f botserver.log | grep -iE "(whatsapp|Extracted|content)"

# Ver estrutura do webhook recebido
tail -f botserver.log | grep -A10 "WhatsApp webhook received"

# Testar webhook manualmente
/tmp/test_whatsapp_webhook.sh

# Verificar configuração do bot
cat /opt/gbo/data/salesianos.gbai/salesianos.gbot/config.csv | grep whatsapp
```

---

## Fase 5: Produção

- [ ] **Configurar SSL/TLS**
  - Certificado válido para o domínio
  - HTTPS obrigatório para webhooks

- [ ] **Rate Limiting**
  - Verificar limites da API do WhatsApp
  - Implementar throttling se necessário

- [ ] **Monitoramento**
  - Alertas para falhas de webhook
  - Logs estruturados

- [ ] **Backup do config.csv**
  - Salvar configurações em local seguro
  - Documentar credenciais (exceto secrets)

---

## Referências

- [WhatsApp Business API Docs](https://developers.facebook.com/docs/whatsapp/business-platform-api)
- [Meta Business Suite](https://business.facebook.com/)
- Arquivo de config: `/opt/gbo/data/salesianos.gbai/salesianos.gbot/config.csv`
- Webhook handler: `gb/botserver/src/whatsapp/mod.rs`

---

## Notas

- **Client Token** fornecido é temporário - necessário Permanent Access Token
- Token permanente deve ser armazenado com segurança (Vault)
- Webhook precisa ser acessível publicamente para receber mensagens