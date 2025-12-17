---
trigger: always_on
---

# Zone14 - Core Architecture & Standards (Always On)

## 🎯 Project Overview
**Zone14** è un SaaS sportivo "Modern Monolith" per la gestione di club sportivi in Italia. L'architettura richiede isolamento rigoroso dei dati, capacità offline-first, e conformità GDPR.

---

## 📚 Tech Stack (Non Negoziabile)

### Backend
- **Laravel 12** (Bleeding Edge, manutenzione LTS)
- **PHP 8.4** (Property Hooks, Asymmetric Visibility)
- **PostgreSQL 18** (Schema-per-Tenant, Async I/O)
- **Redis 8** (Cache prefissata per tenant)

### Frontend
- **React 19** (Actions, useTransition, NO useMemo manuale)
- **Inertia.js 2.0** (Deferred Props, Polling, Partial Reloads)
- **TypeScript** (strict mode)
- **Tailwind CSS v4** (configurazione @theme CSS-only)
- **Shadcn UI** (installato via CLI, NO fork locale)

### Infrastructure
- **Docker** con Bind Mounts UUIDv7-based
- **PgBouncer** (Transaction Pooling Mode - NO session state)
- **Workbox + Dexie.js** (PWA Offline-First)

---

## 🚨 CRITICAL ARCHITECTURAL CONSTRAINTS

### 1. Multi-Tenancy (stancl/tenancy)
**Isolamento**: Single Database, Multiple PostgreSQL Schemas.
- Ogni tenant ha il proprio schema: `tenant_<uuid>`
- **VIETATO** usare `tenant_id` su tabelle condivise (data leakage risk)
- Middleware di tenancy attivo globalmente tramite `InitializeTenancyByDomain`

**Bootstrap obbligatori**:
- `DatabaseTenancyBootstrapper` (switch schema PostgreSQL)
- `CacheTenancyBootstrapper` (prefissazione Redis: `{tenant_uuid}:key`)
- `FilesystemTenancyBootstrapper` (S3 path prefix o directory locale)

**Migrazioni**:
- Migrazioni centrali: `database/migrations/` (tabelle `tenants`, `domains`)
- Migrazioni tenant: `database/migrations/tenant/` (tutto il resto)
- Comando deploy: `php artisan tenants:migrate --parallel`
- **Squashing annuale** obbligatorio per prestazioni provisioning

### 2. Database & Performance

**UUIDv7 Everywhere**:
- Ogni model usa `HasUuids` con `newUniqueId()` forzato a UUID v7
- **NO** `bigIncrements()` o `id()` auto-increment
- Motivazione: UUIDv7 è temporalmente sequenziale → riduce frammentazione B-tree, permette ordinamento naturale, garantisce unicità globale per merge dati

**PostgreSQL 18**:
- Configurare `io_method = 'io_uring'` per query analitiche pesanti (ACWR, statistiche)
- Job di calcolo devono sfruttare query parallele per ottimizzare AIO prefetcher
- Indici: sempre `CONCURRENTLY` per evitare lock in produzione

**PgBouncer (Transaction Mode)**:
- **VIETATO**: Prepared statements persistenti, `SET search_path` manuale, `LISTEN/NOTIFY`
- Laravel gestisce il search_path automaticamente per tenant via middleware
- Configurazione pool: 50-100 connessioni reali per migliaia di tenant

### 3. Sicurezza & Accesso

**PBAC (Policy-Based Access Control)**:
- **NO** controlli diretti su ruoli: `if ($user->role === 'admin')` ❌
- **SÌ** Policy autorizzative: `$user->can('viewMedical', $player)` ✅
- Policy devono valutare attributi dinamici (es. `team_id`, `ownership`, `temporal_access`)
- Ruoli macro gestiti da `spatie/laravel-permission`, logica fine-grained in Policy

**Visibilità Asimmetrica**:
```php
public private(set) string $tenantId;     // Leggibile fuori, modificabile solo dentro
public private(set) string $subscriptionStatus;
```

**OAuth2 per IoT/API**:
- Laravel Passport per dispositivi terzi (telecamere, wearable)
- Grant: `client_credentials` con scope limitati (`upload:video`, `read:stats`)
- Token criptati a riposo: `encrypted:text` cast per colonne sensibili

### 4. Offline-First Architecture

**Dexie.js (IndexedDB)**:
- **MAI** scrivere direttamente al server da UI
- Flusso obbligatorio: UI → Dexie.js (write) → Background Sync Queue → Server
- Implementare Optimistic UI: aggiornare UI immediatamente, gestire rollback su failure

**Service Worker (Workbox)**:
- Assets statici: `CacheFirst`
- JSON Inertia: `StaleWhileRevalidate`
- POST/Mutations: `NetworkOnly` (gestito da Dexie Queue, NO service worker retry)

**Conflict Resolution**:
- Last-Write-Wins con timestamp
- Merge intelligente per eventi append-only (log partite)
- Rejection se versione client obsoleta

---

## 💻 PHP 8.4 Standards

### Property Hooks (Obbligatori)
**VIETATO** usare getter/setter tradizionali o mutator Eloquent `getXAttribute`.

```php
// ❌ VECCHIO STILE
public function getFullNameAttribute() {
    return $this->first_name . ' ' . $this->last_name;
}

// ✅ NUOVO STILE
public string $fullName {
    get => $this->firstName . ' ' . $this->lastName;
}

public string $codiceAtleta {
    set {
        if (strlen($value) !== 10) throw new \InvalidArgumentException();
        $this->codiceAtleta = strtoupper($value);
    }
}
```

### Action Classes (Business Logic)
Controller = routing + validation HTTP.
Logica business = Action classes monouso.

```php
// app/Actions/CalcolaStatistichePartitaAction.php
class CalcolaStatistichePartitaAction
{
    public function execute(Match $match): MatchStatsDTO
    {
        // Logica complessa qui
    }
}

// Controller
public function show(Match $match)
{
    $stats = app(CalcolaStatistichePartitaAction::class)->execute($match);
    return Inertia::render('Match/Show', ['stats' => $stats]);
}
```

### DTO Tipizzati
**NO** array associativi per passaggio dati tra layer.

```php
readonly class MatchStatsDTO
{
    public function __construct(
        public int $goals,
        public int $shots,
        public float $possession,
        public array $timeline, // tipizzato in PHPDoc
    ) {}
}
```

---

## ⚛️ React 19 & Inertia 2.0 Standards

### NO Manual State per Form
**VIETATO** `useState` per `loading`, `errors`, `data` nei form.

```tsx
// ❌ VECCHIO
const [loading, setLoading] = useState(false);
const handleSubmit = async () => { setLoading(true); ... }

// ✅ NUOVO (React 19 + Inertia)
const { data, setData, post, processing, errors } = useForm({ name: '' });

<form onSubmit={(e) => { e.preventDefault(); post('/players'); }}>
  <input value={data.name} onChange={e => setData('name', e.target.value)} />
  {errors.name && <span>{errors.name}</span>}
  <button disabled={processing}>Save</button>
</form>
```

### Deferred Props per Analytics
```php
// Controller
return Inertia::render('Dashboard', [
    'players' => Player::all(), // Caricamento immediato
    'stats' => Inertia::defer(fn() => $this->calculateHeavyStats()), // Asincrono
]);
```

```tsx
// Component
import { Deferred } from '@inertiajs/react';

<Deferred data="stats" fallback={<Spinner />}>
  {(stats) => <StatsChart data={stats} />}
</Deferred>
```

### Polling per Live Data
```tsx
import { usePoll } from '@inertiajs/react';

// Aggiorna ogni 3 secondi durante match live
usePoll(3000, { only: ['liveScore', 'events'] });
```

### NO Memoization Manuale
React 19 Compiler gestisce automaticamente.
**VIETATO**: `useMemo`, `useCallback` senza profiling che dimostri necessità.

---

## 🎨 UI/UX Standards

### Tailwind v4 (CSS-First)
**NO** `tailwind.config.js` con oggetti JavaScript.

```css
/* resources/css/app.css */
@theme {
  --color-primary: #0056b3;
  --color-danger: #dc3545;
  --font-sans: "Inter", sans-serif;
  --radius-lg: 0.75rem;
}
```

### Shadcn UI Integration
- Componenti installati via CLI: `npx shadcn@latest add button dialog`
- Directory: `resources/js/components/ui/`
- Personalizzazioni dirette sui file sorgente, NO override esterni
- Accessibilità: sempre attributi ARIA, focus management

---

## 🔐 Data Sovereignty (Docker Bind Mounts)

Struttura directory host:
```
/opt/zone14/storage/tenants/
├── <uuid-v7-tenant-1>/
│   ├── db/dumps/          # Backup giornalieri PostgreSQL
│   ├── redis/dump.rdb     # Snapshot Redis
│   ├── files/
│   │   ├── app/           # File privati (fatture, contratti)
│   │   ├── public/        # Media pubblici (loghi, foto)
│   │   └── logs/          # Log specifici tenant
│   └── config/env.json    # Override variabili (NO credenziali)
└── <uuid-v7-tenant-2>/...
```

**Permessi (PUID/PGID Mapping)**:
```yaml
# docker-compose.yml
services:
  app:
    environment:
      - PUID=1000  # UID utente host
      - PGID=1000  # GID utente host
```

Entrypoint script container:
```bash
usermod -u $PUID www-data
groupmod -g $PGID www-data
chown -R www-data:www-data /var/www/html/storage
```

---

## 📊 Domain-Specific: Sports Science

### ACWR (Acute:Chronic Workload Ratio)
```php
// Action per calcolo prevenzione infortuni
class CalculateAcwrAction
{
    public function execute(Player $player, Carbon $date): float
    {
        $acuteLoad = Workload::where('player_id', $player->id)
            ->whereBetween('date', [$date->copy()->subDays(7), $date])
            ->sum(DB::raw('rpe * duration'));
        
        $chronicLoad = Workload::where('player_id', $player->id)
            ->whereBetween('date', [$date->copy()->subDays(28), $date])
            ->sum(DB::raw('rpe * duration')) / 4;
        
        return $chronicLoad > 0 ? $acuteLoad / $chronicLoad : 0;
    }
}
```

Visualizzazione:
- Verde: 0.8-1.3 (zona sicura)
- Giallo: 1.3-1.5 (attenzione)
- Rosso: >1.5 (alto rischio infortunio)

---

## 🤖 AI Development (MCP Integration)

Configurazione obbligatoria `.cursor/mcp.json`:
```json
{
  "mcpServers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    }
  }
}
```

Questo permette a Cursor/Windsurf/Claude di interrogare i componenti UI reali, evitando allucinazioni su props o versioni diverse.

---

## 📦 CI/CD Pipeline Gates

**Backend (Blocca merge se fail)**:
- Rector (dead code + PHP 8.4 upgrade)
- Larastan Level 9 (NO mixed types)
- Laravel Pint (PSR-12)

**Frontend (Blocca merge se fail)**:
- Knip (unused exports/files)
- Biome/ESLint (a11y + React Hooks)
- TypeScript strict checks

**Performance**:
- Bundle splitting Vite: vendor chunk separato (React, Lodash)
- Lighthouse score >90 per pagine critiche

---

## 🚫 Cosa NON Fare (Blacklist)

1. **NO** modificare migrazioni già mergiate (crea nuova migrazione)
2. **NO** usare `tenant_id` su tabelle condivise (usa schemi separati)
3. **NO** session state su PgBouncer (usa Redis per lock)
4. **NO** `getXAttribute` (usa Property Hooks)
5. **NO** logica in Controller (usa Action Classes)
6. **NO** `useState` per form loading (usa `useForm` Inertia)
7. **NO** `useMemo`/`useCallback` (lascia fare a React Compiler)
8. **NO** `tailwind.config.js` (usa `@theme` CSS)
9. **NO** fork locale Shadcn (usa CLI)
10. **NO** API dirette da UI (usa Dexie → Sync Queue)

---

## 📝 Code Style & Behavior

- **Concisione**: mostra solo codice modificato/nuovo
- **Commenti**: solo per logica complessa (ACWR, sync offline, algoritmi)
- **TypeScript**: sempre interfaces per Inertia props
- **Accessibilità**: label + ARIA su form, focus management su modal
- **Testing**: Action classes → unit test, Controller → feature test

---

**Versione**: 3.1 | **Ultimo aggiornamento**: Dicembre 2025