#!/bin/bash
curl -X POST http://localhost:8080/webhook/whatsapp/default \
-H "Content-Type: application/json" \
-H "X-Hub-Signature-256: sha256=dummy" \
-d '{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "1234567890",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "552140402160",
              "phone_number_id": "323250907549153"
            },
            "contacts": [
              {
                "profile": {
                  "name": "Test User"
                },
                "wa_id": "5511999999999"
              }
            ],
            "messages": [
              {
                "from": "5511999999999",
                "id": "wamid.simulated_1",
                "timestamp": "1625688536",
                "text": {
                  "body": "cristo"
                },
                "type": "text"
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'
