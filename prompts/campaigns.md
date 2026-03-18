# Email Campaigns — Feature Plan

## Existing Foundation (botserver/src/marketing/)
- `campaigns.rs` — CrmCampaign model, CRUD handlers
- `metrics.rs` — CampaignMetrics, ChannelBreakdown, open/click/conversion rates
- `lists.rs` — recipient lists
- `templates.rs` — content templates
- `triggers.rs` — event-based sending
- `email/tracking.rs` — open/click tracking pixels

---

## Features to Build

### 1. Insights Dashboard
**What:** Time series views of delivery + engagement metrics per campaign.

**Data points per time bucket (hourly/daily):**
- Sent, delivered, bounced, failed
- Opens (unique + total), clicks, replies, unsubscribes
- Delivery rate, open rate, click-to-open rate (CTOR)

**Filters/pivots:**
- By mailbox provider (Gmail, Outlook, Yahoo, etc. — parsed from MX/SMTP response)
- By sender identity (from address / domain)
- By campaign or list
- Message search → show exact SMTP response from provider

**Implementation:**
- Add `email_delivery_events` table: `(id, campaign_id, recipient_id, event_type, provider, smtp_response, ts)`
- API: `GET /api/campaigns/:id/insights?from=&to=&group_by=provider|identity|day`
- UI: HTMX + chart.js time series (local vendor)

---

### 2. Advisor Recommendations
**What:** Analyze sending config + results and surface actionable fixes.

**Checks to run:**
| Check | Signal | Recommendation |
|---|---|---|
| SPF/DKIM/DMARC | DNS lookup | "Add missing record" |
| Bounce rate > 5% | delivery_events | "Clean list — remove hard bounces" |
| Open rate < 15% | metrics | "Improve subject line / send time" |
| Spam complaints > 0.1% | FBL data | "Remove complainers immediately" |
| Sending from new IP | warmup_schedule | "Follow warmup plan" |
| List age > 6 months | list.last_sent | "Re-engagement campaign before bulk send" |

**Implementation:**
- `marketing/advisor.rs` — `AdvisorEngine::analyze(campaign_id) -> Vec<Recommendation>`
- API: `GET /api/campaigns/:id/advisor`
- Runs automatically after each campaign completes

---

### 3. IP Warmup (like OneSignal / Mailchimp)
**What:** Gradually increase daily send volume over 4–6 weeks to build sender reputation.

**Warmup schedule (standard):**
| Day | Max emails/day |
|---|---|
| 1–2 | 50 |
| 3–4 | 100 |
| 5–7 | 500 |
| 8–10 | 1,000 |
| 11–14 | 5,000 |
| 15–21 | 10,000 |
| 22–28 | 50,000 |
| 29+ | unlimited |

**Rules:**
- Only send to most engaged subscribers first (opened in last 90 days)
- Stop warmup if bounce rate > 3% or complaint rate > 0.1%
- Resume next day at same volume if paused

**Implementation:**
- `marketing/warmup.rs` — `WarmupSchedule`, `WarmupEngine::get_daily_limit(ip, day) -> u32`
- `warmup_schedules` table: `(id, ip, started_at, current_day, status, paused_reason)`
- Scheduler checks warmup limit before each send batch
- API: `GET /api/warmup/status`, `POST /api/warmup/start`

---

### 4. Optimized Shared Delivery
**What:** Auto-select best sending IP based on real-time reputation signals.

**Logic:**
- Track per-IP: bounce rate, complaint rate, delivery rate (last 24h)
- Score each IP: `score = delivery_rate - (bounce_rate * 10) - (complaint_rate * 100)`
- Route each send to highest-scored IP for that destination provider
- Rotate IPs to spread load and preserve reputation

**Implementation:**
- `marketing/ip_router.rs` — `IpRouter::select(destination_domain) -> IpAddr`
- `ip_reputation` table: `(ip, provider, bounces, complaints, delivered, window_start)`
- Plugs into Stalwart send path via botserver API

---

### 5. Modern Email Marketing Features

| Feature | Description |
|---|---|
| **Send time optimization** | ML-based per-contact best send time (based on past open history) |
| **A/B testing** | Split subject/content, auto-pick winner after N hours |
| **Suppression list** | Global unsubscribe/bounce/complaint list, auto-applied to all sends |
| **Re-engagement flows** | Auto-trigger "we miss you" to contacts inactive > 90 days |
| **Transactional + marketing separation** | Separate IPs/domains for transactional vs bulk |
| **One-click unsubscribe** | RFC 8058 `List-Unsubscribe-Post` header on all bulk sends |
| **Preview & spam score** | Pre-send SpamAssassin score check |
| **Link tracking** | Redirect all links through tracker, record clicks per contact |
| **Webhook events** | Push delivery events to external URLs (Stalwart webhook → botserver) |

---

## DB Tables to Add

```sql
email_delivery_events (id, campaign_id, recipient_id, event_type, provider, smtp_code, smtp_response, ts)
warmup_schedules      (id, ip, started_at, current_day, daily_limit, status, paused_reason)
ip_reputation         (id, ip, provider, delivered, bounced, complained, window_start)
advisor_recommendations (id, campaign_id, check_name, severity, message, created_at, dismissed)
ab_tests              (id, campaign_id, variant_a, variant_b, split_pct, winner, decided_at)
suppression_list      (id, org_id, email, reason, added_at)
```

---

## Files to Create
```
botserver/src/marketing/
├── warmup.rs          — IP warmup engine + schedule
├── advisor.rs         — recommendation engine
├── ip_router.rs       — optimized IP selection
├── ab_test.rs         — A/B test logic
├── suppression.rs     — global suppression list
└── send_time.rs       — send time optimization
```

---

## Existing Code to Extend
- `marketing/metrics.rs` → add time-series queries + provider breakdown
- `marketing/campaigns.rs` → add warmup_enabled, ab_test_id fields
- `email/tracking.rs` → already has open/click tracking, extend with provider parsing
- `core/shared/schema/` → add new tables above
