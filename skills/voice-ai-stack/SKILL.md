---
name: voice-ai-stack
description: >
  Voice AI agent development using Telnyx for SIP/SMS telephony, ElevenLabs Conversational
  AI for the STT-LLM-TTS pipeline, and a custom-built booking engine on Cloudflare Workers.
  Covers call flow design, SIP trunk configuration, ElevenLabs agent setup, real-time
  transcription, booking logic, mini CRM patterns, and SMS follow-up. Do NOT suggest Retell
  AI — ElevenLabs is the mandatory choice. Use when building voice AI agents, phone bots,
  booking systems, IVR replacements, or any telephony integration. Triggers on: "voice AI",
  "phone bot", "call", "SIP", "Telnyx", "ElevenLabs", "booking agent", "IVR", "telephony",
  "receptionist", "inbound call", "outbound call", "SMS", "text message", "conversational
  AI", "STT", "TTS", or "speech".
---

# Voice AI Stack Skill

Custom skill — no agency-agents equivalent exists. Built for __COMPANY_NAME__'s
preferred voice stack: Telnyx + ElevenLabs + Cloudflare Workers.

**Never suggest Retell AI.** ElevenLabs Conversational AI is the mandatory
STT-LLM-TTS pipeline for all __COMPANY_NAME__ voice projects.

## Architecture

```
Inbound call (PSTN)
        │
        ▼
┌──────────────────┐
│  Telnyx SIP      │ ← Receives call, provides SIP trunk + phone numbers
│  Trunk           │ ← Handles SMS sending/receiving
└────────┬─────────┘
         │ WebSocket / SIP INVITE
         ▼
┌──────────────────┐
│  ElevenLabs      │ ← Real-time STT → LLM reasoning → TTS
│  Conversational  │ ← Handles turn-taking, interruptions, silence detection
│  AI              │ ← Custom tools for booking, lookup, transfer
└────────┬─────────┘
         │ Tool calls via webhook
         ▼
┌──────────────────┐
│  Cloudflare      │ ← Booking engine: check availability, create appointment
│  Workers         │ ← Mini CRM: caller lookup, history, preferences
│  (Custom)        │ ← SMS follow-up via Telnyx API
│                  │ ← Data stored in D1
└──────────────────┘
```

## Telnyx Configuration

### Phone Number Setup
```bash
# Via Telnyx dashboard or API:
# 1. Purchase a phone number (local or toll-free)
# 2. Create a SIP trunk / TeXML application
# 3. Point inbound calls to your webhook or SIP endpoint
# 4. Configure SMS webhook for the same number
```

### Telnyx API (Workers)
```typescript
// src/lib/server/telnyx.ts
const TELNYX_API = 'https://api.telnyx.com/v2';

export async function sendSMS(env: Env, to: string, body: string) {
  const response = await fetch(`${TELNYX_API}/messages`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.TELNYX_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: env.TELNYX_PHONE_NUMBER,
      to,
      text: body,
      messaging_profile_id: env.TELNYX_MSG_PROFILE_ID,
    }),
  });
  return response.json();
}

export async function initiateCall(env: Env, to: string, webhookUrl: string) {
  const response = await fetch(`${TELNYX_API}/calls`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.TELNYX_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      connection_id: env.TELNYX_CONNECTION_ID,
      to,
      from: env.TELNYX_PHONE_NUMBER,
      webhook_url: webhookUrl,
    }),
  });
  return response.json();
}
```

### Telnyx Webhook Handler
```typescript
// src/routes/api/telnyx/webhook/+server.ts
export async function POST({ request, platform }) {
  const event = await request.json();
  const env = platform?.env;

  switch (event.data.event_type) {
    case 'call.initiated':
      // Call started — log to D1
      await logCallEvent(env, event.data.payload);
      break;

    case 'call.answered':
      // Connect to ElevenLabs Conversational AI
      await bridgeToElevenLabs(env, event.data.payload);
      break;

    case 'call.hangup':
      // Call ended — trigger SMS follow-up
      await handleCallEnd(env, event.data.payload);
      break;

    case 'message.received':
      // Inbound SMS — route to handler
      await handleInboundSMS(env, event.data.payload);
      break;
  }

  return new Response('ok');
}
```

## ElevenLabs Conversational AI

### Agent Configuration

ElevenLabs agents are configured via their dashboard or API. Key settings:

```json
{
  "name": "__COMPANY_NAME__ Receptionist",
  "voice_id": "your-chosen-voice-id",
  "model": "eleven_turbo_v2_5",
  "language": "en",
  "first_message": "Thanks for calling! How can I help you today?",
  "system_prompt": "You are a friendly receptionist for [Business Name]. Your job is to help callers book appointments, answer questions about services, and take messages. Be warm, professional, and concise. If you can't help, offer to transfer to a human.",
  "tools": [
    {
      "name": "check_availability",
      "description": "Check available appointment slots for a given date and service type",
      "webhook_url": "https://myapp.workers.dev/api/voice/tools/availability"
    },
    {
      "name": "book_appointment",
      "description": "Book an appointment for the caller",
      "webhook_url": "https://myapp.workers.dev/api/voice/tools/book"
    },
    {
      "name": "lookup_customer",
      "description": "Look up a customer by phone number",
      "webhook_url": "https://myapp.workers.dev/api/voice/tools/lookup"
    }
  ],
  "conversation_config": {
    "max_duration_seconds": 300,
    "silence_timeout_seconds": 10,
    "interruption_sensitivity": 0.7
  }
}
```

### Tool Webhook Handlers

```typescript
// src/routes/api/voice/tools/availability/+server.ts
export async function POST({ request, platform }) {
  const { date, service_type } = await request.json();
  const env = platform?.env;

  const slots = await env.DB
    .prepare(`
      SELECT time_slot, duration_minutes
      FROM availability
      WHERE date = ? AND service_type = ? AND is_booked = FALSE
      ORDER BY time_slot
    `)
    .bind(date, service_type)
    .all();

  return Response.json({
    available_slots: slots.results.map(s => ({
      time: s.time_slot,
      duration: s.duration_minutes,
    })),
  });
}

// src/routes/api/voice/tools/book/+server.ts
export async function POST({ request, platform }) {
  const { customer_phone, date, time_slot, service_type, customer_name } = await request.json();
  const env = platform?.env;

  // Create or update customer
  await env.DB.prepare(`
    INSERT INTO customers (phone, name, last_contact)
    VALUES (?, ?, datetime('now'))
    ON CONFLICT(phone) DO UPDATE SET name = ?, last_contact = datetime('now')
  `).bind(customer_phone, customer_name, customer_name).run();

  // Book the slot
  await env.DB.prepare(`
    UPDATE availability SET is_booked = TRUE, customer_phone = ?
    WHERE date = ? AND time_slot = ? AND service_type = ?
  `).bind(customer_phone, date, time_slot, service_type).run();

  // Create appointment record
  await env.DB.prepare(`
    INSERT INTO appointments (customer_phone, date, time_slot, service_type, status)
    VALUES (?, ?, ?, ?, 'confirmed')
  `).bind(customer_phone, date, time_slot, service_type).run();

  // Send confirmation SMS
  await sendSMS(env, customer_phone,
    `Your ${service_type} appointment is confirmed for ${date} at ${time_slot}. Reply CANCEL to cancel.`
  );

  return Response.json({ success: true, message: 'Appointment booked and SMS confirmation sent' });
}
```

## Mini CRM Schema (D1)

```sql
-- migrations/0001_voice_crm.sql
CREATE TABLE customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT UNIQUE NOT NULL,
  name TEXT,
  email TEXT,
  notes TEXT,
  total_calls INTEGER DEFAULT 0,
  last_contact TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE appointments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_phone TEXT NOT NULL REFERENCES customers(phone),
  date TEXT NOT NULL,
  time_slot TEXT NOT NULL,
  service_type TEXT NOT NULL,
  status TEXT DEFAULT 'confirmed',  -- confirmed, completed, cancelled, no-show
  notes TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE availability (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  time_slot TEXT NOT NULL,
  duration_minutes INTEGER DEFAULT 30,
  service_type TEXT NOT NULL,
  is_booked BOOLEAN DEFAULT FALSE,
  customer_phone TEXT,
  UNIQUE(date, time_slot, service_type)
);

CREATE TABLE call_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  call_id TEXT UNIQUE NOT NULL,
  customer_phone TEXT,
  direction TEXT NOT NULL,  -- inbound, outbound
  duration_seconds INTEGER,
  transcript TEXT,
  sentiment TEXT,  -- positive, neutral, negative
  outcome TEXT,    -- booked, inquiry, transfer, voicemail
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE sms_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_phone TEXT NOT NULL,
  direction TEXT NOT NULL,  -- inbound, outbound
  body TEXT NOT NULL,
  telnyx_message_id TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_appointments_date ON appointments(date);
CREATE INDEX idx_appointments_customer ON appointments(customer_phone);
CREATE INDEX idx_availability_date ON availability(date, is_booked);
CREATE INDEX idx_call_log_phone ON call_log(customer_phone);
```

## Post-Call Workflow

```typescript
async function handleCallEnd(env: Env, payload: TelnyxCallPayload) {
  const { call_control_id, from, duration_seconds } = payload;

  // 1. Update call log with duration
  await env.DB.prepare(
    'UPDATE call_log SET duration_seconds = ? WHERE call_id = ?'
  ).bind(duration_seconds, call_control_id).run();

  // 2. Increment customer call count
  await env.DB.prepare(
    'UPDATE customers SET total_calls = total_calls + 1 WHERE phone = ?'
  ).bind(from).run();

  // 3. If appointment was booked, send reminder SMS 24h before
  // (schedule via Cloudflare Queues or Cron Triggers)

  // 4. If no appointment booked, send follow-up SMS
  const hasAppointment = await env.DB
    .prepare('SELECT id FROM appointments WHERE customer_phone = ? AND date >= date("now") LIMIT 1')
    .bind(from)
    .first();

  if (!hasAppointment) {
    await sendSMS(env, from,
      "Thanks for calling! If you'd like to book an appointment, reply BOOK or call us back anytime."
    );
  }
}
```

## SMS Handling

```typescript
// Inbound SMS router
async function handleInboundSMS(env: Env, payload: TelnyxSMSPayload) {
  const { from, text } = payload;
  const body = text.trim().toUpperCase();

  // Log inbound
  await env.DB.prepare(
    'INSERT INTO sms_log (customer_phone, direction, body, telnyx_message_id) VALUES (?, ?, ?, ?)'
  ).bind(from.phone_number, 'inbound', text, payload.id).run();

  switch (body) {
    case 'CANCEL':
      await cancelNextAppointment(env, from.phone_number);
      await sendSMS(env, from.phone_number, 'Your next appointment has been cancelled.');
      break;

    case 'BOOK':
      await sendSMS(env, from.phone_number,
        'To book, please call us or visit our website. We have openings this week!'
      );
      break;

    case 'CONFIRM':
      await confirmNextAppointment(env, from.phone_number);
      await sendSMS(env, from.phone_number, 'Your appointment is confirmed. See you soon!');
      break;

    default:
      // Unknown — log and optionally notify staff
      break;
  }
}
```

## Required Secrets

```bash
wrangler secret put TELNYX_API_KEY
wrangler secret put TELNYX_PHONE_NUMBER
wrangler secret put TELNYX_CONNECTION_ID
wrangler secret put TELNYX_MSG_PROFILE_ID
wrangler secret put ELEVENLABS_API_KEY
```

## Product B Use Case (__COMPANY_NAME__ Product)

For the Product B product specifically:
- **Service types**: cleaning, exam, filling, crown, emergency
- **Availability**: Pull from practice management system or manual entry
- **Insurance check**: Tool that asks for insurance info, logs for staff review
- **Recall/reactivation**: Outbound calls to patients overdue for cleaning
- **After-hours**: Voice agent handles calls 24/7, books or takes messages

## Relationship to Other Skills

- **Loaded by**: AI/ML Lead agent (primary), App Dev Lead (booking engine)
- **Data layer**: `d1-optimizer` (query patterns), `drizzle-schema` (ORM)
- **PII handling**: `data-remediation` (transcript PII redaction)
- **Deployed by**: `axiom-cicd`, `devops-automator` (Wrangler secrets)
