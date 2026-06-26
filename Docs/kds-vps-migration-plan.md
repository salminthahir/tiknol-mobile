# KDS (Kitchen Display System) - VPS Migration Plan

> **Dibuat:** 26 Juni 2026, 14:30 WIB
> **Status:** Planning (Future Migration)
> **Backend:** Next.js on Linux VPS (No Supabase)
> **Scope:** Backend & Frontend Migration dari Supabase ke Self-Hosted

---

## 1. Ringkasan Eksekutif

Dokumen ini merencanakan migrasi KDS dari **Supabase Realtime** ke **self-hosted solution** di Linux VPS. Karena production tidak akan menggunakan Supabase, diperlukan mekanisme real-time alternatif untuk mengirim order baru ke kitchen display.

### Tujuan
- Menghilangkan dependency Supabase dari production
- Menyediakan real-time order push ke KDS via mekanisme self-hosted
- Menjaga performa & reliability yang sama dengan Supabase Realtime
- Minimal downtime saat migrasi

---

## 2. Kondisi Saat Ini vs Target

| Aspek | Saat Ini (Supabase) | Target (VPS) |
|---|---|---|
| **Hosting** | Vercel Serverless + Supabase | Linux VPS (dedicated) |
| **Database** | PostgreSQL via Supabase | PostgreSQL via Prisma (self-hosted) |
| **Real-time** | Supabase Realtime (postgres_changes) | Self-hosted solution |
| **Auth** | Cookie-based session | Tetap sama |
| **WebSocket** | Via Supabase (managed) | Harus dibuat sendiri |

---

## 3. Opsi Arsitektur Real-Time untuk VPS

### Opsi A: HTTP Polling (Paling Simpel)

```
┌─────────────┐     GET /api/admin/orders      ┌─────────────┐
│  Flutter    │◄───────────────────────────────►│  Next.js    │
│  KDS App    │     Setiap 5-10 detik           │  API Routes │
│  (Timer)    │                                 │  (VPS)      │
└─────────────┘                                 └─────────────┘
```

**Implementasi Backend:** Tidak ada perubahan — endpoint `/api/admin/orders` sudah ada.

**Implementasi Flutter:**
```dart
// Polling setiap 5 detik
Timer.periodic(Duration(seconds: 5), (_) async {
  final orders = await fetchOrders();
  // Bandingkan dengan state sebelumnya
  // Trigger alert jika ada order baru
});
```

| ✅ Kelebihan | ❌ Kekurangan |
|---|---|
| Tidak perlu ubah backend | Delay 5-10 detik |
| Paling simpel diimplementasi | Boros bandwidth (request periodik) |
| Stabil & predictable | Baterai lebih boros |
| Bisa langsung dikerjakan | Tidak real-time |

**Resource Impact:**
- Network: 720-1,440 request/jam per device
- 3 device kitchen = 2,160-4,320 request/jam
- VPS 1-2 CPU core masih sanggup, tapi tidak scalable

---

### Opsi B: Server-Sent Events / SSE (Rekomendasi)

```
┌─────────────┐     HTTP GET (persistent)      ┌─────────────┐
│  Flutter    │◄──────────────────────────────►│  Next.js    │
│  KDS App    │     text/event-stream           │  SSE        │
└─────────────┘                                 │  Endpoint   │
                                                └─────────────┘
```

**Cara Kerja:**
1. Flutter buka koneksi HTTP ke `/api/admin/orders/stream`
2. Server mempertahankan koneksi terbuka (long-lived HTTP)
3. Saat ada INSERT/UPDATE di database, server push event ke semua client
4. Client menerima event → update UI + trigger alert

**Implementasi Backend (Next.js):**

```typescript
// app/api/admin/orders/stream/route.ts
import { prisma } from '@/lib/prisma';
import { EventEmitter } from 'events';

const orderEmitter = new EventEmitter();

// Dipanggil dari order creation/update endpoints
export function notifyOrderChange(branchId: string, type: 'INSERT' | 'UPDATE', order: any) {
  orderEmitter.emit(`order-${branchId}`, { type, order });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const branchId = searchParams.get('branchId') || '';

  const stream = new ReadableStream({
    start(controller) {
      const encoder = new TextEncoder();

      const sendEvent = (data: any) => {
        const message = `data: ${JSON.stringify(data)}\n\n`;
        controller.enqueue(encoder.encode(message));
      };

      // Kirim initial data
      sendEvent({ type: 'INIT', timestamp: Date.now() });

      // Heartbeat setiap 30 detik
      const heartbeat = setInterval(() => {
        sendEvent({ type: 'HEARTBEAT', timestamp: Date.now() });
      }, 30000);

      // Listen perubahan order
      const handler = (data: any) => sendEvent(data);
      orderEmitter.on(`order-${branchId}`, handler);

      // Cleanup saat client disconnect
      request.signal.addEventListener('abort', () => {
        clearInterval(heartbeat);
        orderEmitter.off(`order-${branchId}`, handler);
        controller.close();
      });
    }
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}
```

**Perubahan di Endpoint Order:**
```typescript
// app/api/cash-order/route.ts (tambahkan di akhir)
import { notifyOrderChange } from '../admin/orders/stream/route';

// Setelah order tersimpan:
notifyOrderChange(branchId, 'INSERT', newOrder);
```

**Implementasi Flutter:**
```dart
// lib/services/sse_service.dart
class SSEService {
  Stream<Map<String, dynamic>> connect(String branchId) async* {
    final url = '${Constants.baseUrl}/api/admin/orders/stream?branchId=$branchId';
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final json = jsonDecode(line.substring(6));
          yield json;
        }
      }
    }
  }
}
```

| ✅ Kelebihan | ❌ Kekurangan |
|---|---|
| Real-time push (instan) | Perlu develop backend SSE endpoint |
| 1 koneksi persisten per device (hemat) | Connection management (reconnect) |
| Lebih ringan dari WebSocket | Kurang ekosistem library dibanding WS |
| Compatible dengan HTTP standard | Next.js App Router kurang ideal untuk long-lived connections |

**Resource Impact:**
- Network: 1 persistent connection per device + heartbeat 30 detik
- Memory: Minimal — hanya event listener
- CPU: Negligible

---

### Opsi C: WebSocket Server (Paling Robust)

```
┌─────────────┐     ws://vps:3001              ┌─────────────┐
│  Flutter    │◄──────────────────────────────►│  WS Server  │
│  KDS App    │                                 │  (Node.js)  │
└─────────────┘                                 └──────┬──────┘
                                                       │
                                                       ▼
                                                ┌─────────────┐
                                                │  PostgreSQL  │
                                                │  (trigger)   │
                                                └─────────────┘
```

**Arsitektur:**
- Service terpisah: Node.js + `ws` library di port berbeda (misal 3001)
- Next.js app di port 3000 (existing)
- WebSocket server listen perubahan database (polling DB atau trigger)

**Implementasi Backend (WS Server):**
```typescript
// ws-server/index.ts
import { WebSocketServer } from 'ws';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const wss = new WebSocketServer({ port: 3001 });

// Map branchId → Set<WebSocket>
const clients = new Map<string, Set<WebSocket>>();

wss.on('connection', (ws, req) => {
  const url = new URL(req.url!, `http://${req.headers.host}`);
  const branchId = url.searchParams.get('branchId') || '';

  if (!clients.has(branchId)) {
    clients.set(branchId, new Set());
  }
  clients.get(branchId)!.add(ws);

  ws.on('close', () => {
    clients.get(branchId)?.delete(ws);
  });
});

// Poll database setiap 2 detik untuk perubahan
// (Atau gunakan PostgreSQL LISTEN/NOTIFY)
async function pollOrders() {
  const latest = await prisma.order.findMany({
    where: { status: { notIn: ['COMPLETED', 'FAILED'] } },
    orderBy: { updatedAt: 'desc' },
    take: 100,
  });

  // Broadcast ke semua client per branch
  for (const [branchId, wsSet] of clients) {
    const branchOrders = latest.filter(o => o.branchId === branchId);
    const message = JSON.stringify({ type: 'ORDERS_UPDATE', orders: branchOrders });
    for (const ws of wsSet) {
      if (ws.readyState === ws.OPEN) {
        ws.send(message);
      }
    }
  }
}

setInterval(pollOrders, 2000);
```

**Atau pakai PostgreSQL LISTEN/NOTIFY (lebih efisien):**
```sql
-- Trigger di PostgreSQL
CREATE OR REPLACE FUNCTION notify_order_change()
RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('order_changes', json_build_object(
    'type', TG_OP,
    'orderId', NEW.id,
    'branchId', NEW.branchId,
    'status', NEW.status
  )::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_change_trigger
AFTER INSERT OR UPDATE ON "Order"
FOR EACH ROW EXECUTE FUNCTION notify_order_change();
```

```typescript
// WS Server listen PostgreSQL notification
import { Client } from 'pg';

const pgClient = new Client({ connectionString: process.env.DATABASE_URL });
await pgClient.connect();
await pgClient.query('LISTEN order_changes');

pgClient.on('notification', (msg) => {
  const payload = JSON.parse(msg.payload!);
  const branchClients = clients.get(payload.branchId);
  if (branchClients) {
    for (const ws of branchClients) {
      if (ws.readyState === ws.OPEN) {
        ws.send(JSON.stringify(payload));
      }
    }
  }
});
```

| ✅ Kelebihan | ❌ Kekurangan |
|---|---|
| Full duplex (2 arah) | Paling kompleks |
| Paling scalable (ribuan koneksi) | Service terpisah (DevOps overhead) |
| Industry standard untuk real-time | Perlu manage reconnect, heartbeat |
| Banyak library & contoh | Tambah monitoring & error handling |

**Resource Impact:**
- Network: 1 persistent WS per device
- Memory: ~1MB per 1000 koneksi
- CPU: Negligible kecuali high-traffic
- DevOps: 2 service (Next.js + WS server), perlu process manager (PM2)

---

## 4. Rekomendasi: Fase Bertahap

### Fase 1: Polling (Minggu 1) — Langsung Bisa

**Tujuan:** KDS berfungsi tanpa Supabase, tanpa ubah backend.

| Task | Effort |
|---|---|
| Buat `polling_service.dart` (timer 5 detik) | 2 jam |
| Modifikasi `kitchen_realtime_provider.dart` | 1 jam |
| Deteksi order baru (diff array) | 1 jam |
| Testing | 1 jam |

**Total: ~5 jam**

**Kekurangan:** Delay 5-10 detik. Cukup untuk operasional, tapi tidak ideal.

### Fase 2: SSE (Minggu 2-3) — Upgrade Real-Time

**Tujuan:** Push real-time tanpa delay.

| Task | Effort |
|---|---|
| Buat SSE endpoint di backend | 4 jam |
| Modifikasi order endpoints (emit events) | 2 jam |
| Buat `sse_service.dart` di Flutter | 3 jam |
| Ganti polling dengan SSE | 2 jam |
| Reconnect & error handling | 2 jam |
| Testing | 2 jam |

**Total: ~15 jam (backend + frontend)**

### Fase 3: WebSocket (Opsional) — Skala Besar

**Tujuan:** Skala untuk banyak device / multi-branch.

| Task | Effort |
|---|---|
| Buat WS server (Node.js) | 6 jam |
| Setup PostgreSQL LISTEN/NOTIFY | 3 jam |
| Process manager (PM2) | 2 jam |
| Flutter WS client | 4 jam |
| Testing & monitoring | 3 jam |

**Total: ~18 jam**

---

## 5. Perbandingan Opsi

| Kriteria | Polling | SSE | WebSocket |
|---|---|---|---|
| **Complexity** | ⭐ Sangat rendah | ⭐⭐ Sedang | ⭐⭐⭐ Tinggi |
| **Real-time** | ❌ Delay 5-10s | ✅ Instan | ✅ Instan |
| **Backend Change** | ❌ Tidak ada | ⚠️ Perlu endpoint baru | ⚠️ Perlu service baru |
| **Scalability** | ⭐ Rendah | ⭐⭐ Sedang | ⭐⭐⭐ Tinggi |
| **Resource Usage** | ⭐ Boros | ⭐⭐ Efisien | ⭐⭐ Efisien |
| **DevOps Overhead** | ❌ Tidak ada | ⭐ Minimal | ⚠️ Perlu PM2 & monitoring |
| **Library Flutter** | Built-in | `http` package | `web_socket_channel` |

---

## 6. Flutter Code Changes (Minimal)

### Abstraction Layer

Buat abstraction agar mudah swap antara Supabase, Polling, dan SSE:

```dart
// lib/services/order_stream_service.dart
abstract class OrderStreamService {
  Stream<List<dynamic>> watchOrders(String branchId);
  void dispose();
}

// lib/services/supabase_order_stream.dart
class SupabaseOrderStream implements OrderStreamService {
  @override
  Stream<List<dynamic>> watchOrders(String branchId) {
    // Supabase realtime implementation
  }
}

// lib/services/polling_order_stream.dart
class PollingOrderStream implements OrderStreamService {
  @override
  Stream<List<dynamic>> watchOrders(String branchId) {
    // Timer.periodic polling implementation
  }
}

// lib/services/sse_order_stream.dart
class SSEOrderStream implements OrderStreamService {
  @override
  Stream<List<dynamic>> watchOrders(String branchId) {
    // SSE implementation
  }
}
```

**Provider:**
```dart
// lib/providers/kitchen_realtime_provider.dart
final orderStreamServiceProvider = Provider<OrderStreamService>((ref) {
  // Pilih implementation berdasarkan config
  // Supabase: return SupabaseOrderStream();
  // VPS: return PollingOrderStream(); atau SSEOrderStream();
  return PollingOrderStream(); // Default untuk VPS
});

final kitchenRealtimeProvider = StreamProvider<List<dynamic>>((ref) {
  final auth = ref.watch(authProvider);
  final service = ref.watch(orderStreamServiceProvider);
  return service.watchOrders(auth.branchId ?? '');
});
```

**Dengan abstraction ini, migrasi hanya mengganti 1 baris di provider.**

---

## 7. File yang Perlu Diubah Saat Migrasi

| File | Perubahan | Effort |
|---|---|---|
| `lib/services/supabase_service.dart` | Ganti dengan polling_service.dart atau sse_service.dart | 2 jam |
| `lib/providers/kitchen_realtime_provider.dart` | Ganti data source (sudah di-abstraksi) | 30 menit |
| `pubspec.yaml` | Hapus `supabase_flutter`, tambah `http` (jika perlu) | 15 menit |
| **Total frontend** | | **~3 jam** |

| Backend File | Perubahan | Effort |
|---|---|---|
| `app/api/admin/orders/stream/route.ts` | Buat baru (SSE endpoint) | 4 jam |
| `app/api/cash-order/route.ts` | Tambah event emission | 1 jam |
| `app/api/tokenizer/route.ts` | Tambah event emission | 1 jam |
| **Total backend** | | **~6 jam** |

---

## 8. Timeline Migrasi

```
Week 1 (Sekarang):
├── Development pakai Supabase Realtime
├── Semua fitur KDS di-develop & test
└── Polling code siap sebagai fallback

Week 4+ (VPS Migration):
├── Day 1: Setup VPS + PostgreSQL + deploy Next.js
├── Day 2: Switch Flutter dari Supabase ke Polling (3 jam)
├── Day 3-4: Develop SSE endpoint di backend (6 jam)
├── Day 5: Switch Flutter dari Polling ke SSE (2 jam)
└── Day 6: Testing end-to-end + monitoring
```

---

## 9. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| SSE connection drop | KDS tidak menerima order | Auto-reconnect + fallback ke polling |
| VPS down | Semua KDS mati | Monitoring uptime + restart otomatis (PM2) |
| High traffic crash | WebSocket/SSE koneksi putus | Rate limiting + connection pool |
| Migration downtime | Kitchen tidak bisa terima order | Siapkan polling fallback yang bisa aktif instan |

---

## 10. Checklist Pre-Migration

### Backend (VPS)
- [ ] VPS provisioned (Ubuntu 22.04+, 2+ CPU, 4GB+ RAM)
- [ ] PostgreSQL installed & configured
- [ ] Prisma schema migrated
- [ ] Next.js app deployed & running
- [ ] PM2 configured for auto-restart
- [ ] Domain/SSL configured
- [ ] Firewall rules (port 80, 443, 3000)

### Flutter
- [ ] Abstraction layer `OrderStreamService` implemented
- [ ] Polling fallback tested & working
- [ ] SSE client code ready (commented/behind feature flag)
- [ ] Supabase code removed or behind feature flag
- [ ] App tested tanpa Supabase connection

### Testing
- [ ] KDS menerima order baru (polling)
- [ ] KDS menerima order baru (SSE)
- [ ] Sound & vibration alert berfungsi
- [ ] Timer berjalan dengan benar
- [ ] BUMP bar berfungsi
- [ ] Reconnect setelah koneksi putus
- [ ] Multi-device (3+ kitchen devices)

---

## 11. Referensi

- SSE spec: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events
- PostgreSQL LISTEN/NOTIFY: https://www.postgresql.org/docs/current/sql-notify.html
- Next.js streaming: https://nextjs.org/docs/app/building-your-application/routing/route-handlers#streaming
- Flutter SSE client: `http` package dengan stream response
- PM2 process manager: https://pm2.keymetrics.io/
