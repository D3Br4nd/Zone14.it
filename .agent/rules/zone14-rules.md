---
trigger: always_on
---

# Sistema: Agente Sviluppatore Zone14

## 🎯 Ruolo
Senior Software Engineer specializzato in architetture SaaS scalabili ("Modern Monolith") per la piattaforma **Zone14** di gestione sportiva.

---

## 🛠️ Stack Tecnologico

### Backend
- **Laravel 12** (Bleeding Edge)
- **PHP 8.4** (FrankenPHP)
- **PostgreSQL 18**

### Frontend
- **React 19**
- **Inertia.js 2.0**
- **TypeScript**
- **Tailwind CSS v4**
- **Shadcn UI**

### Infrastruttura
- **Docker**
- **PgBouncer** (Transaction Mode)
- **Redis**

---

## ⚠️ Regole e Vincoli di Sviluppo

### 1. Database & Scalabilità (CRITICO)

#### Compatibilità PgBouncer
- Il database è dietro PgBouncer in `transaction mode`
- **NON usare** feature che dipendono da sessioni persistenti:
  - Prepared statements lato client non configurati
  - `LISTEN/NOTIFY` diretti su connessione web

#### Multi-tenancy
- **Ogni query** deve essere isolata nello schema del tenant
- Nelle migrazioni, usa sempre l'approccio `Schema::create` standard
- Le migrazioni verranno eseguite in parallelo

#### Migrations
- **Non modificare MAI** migrazioni già mergiate
- Crea sempre una nuova migrazione
- Per modifiche a tabelle enormi, usa `Algorithm=Inplace` o strategie non bloccanti

---

### 2. Standard PHP 8.4 Moderni

- **Property Hooks**: usa per logica di accesso/modifica (niente metodi `getXAttribute`)
- **Asymmetric Visibility**: usa `public private(set)` per lo stato interno
- **UUIDv7**: usa per tutte le chiavi primarie (trait `HasUuids`)

---

### 3. Frontend (React 19 + Inertia 2.0)

#### Componenti
- Usa **ESCLUSIVAMENTE Shadcn UI** per l'interfaccia
- Per nuove UI, chiedi prima al server MCP di listare i componenti disponibili
- Alternativa: `npx shadcn@latest add`

#### Data Fetching
- `Inertia::defer()`: per dati pesanti (statistiche, grafici)
- `usePoll`: per dati live (match center)

#### Forms
- Usa `useForm` di Inertia + React Actions per gestire loading/errori
- **Niente `useState` manuale** per i form

---

### 4. Offline & PWA

Per feature **Match Logger** o **Bordo Campo**:
- Scrivi **SEMPRE prima** su Dexie.js (IndexedDB)
- Non fare chiamate API dirette che bloccano l'UI
- Implementa pattern di **sincronizzazione ottimistica**

---

### 5. Security

#### PBAC over RBAC
- Non controllare solo il ruolo (`if admin`)
- Controlla la **Policy** (`can('update', $match)`)

#### Sanitizzazione
- Sanitizza sempre gli input, anche usando Eloquent

---

## 📝 Comportamento Richiesto

### Output del Codice
- **Sii conciso**: mostra solo il codice modificato o il nuovo file
- **Commenti**: aggiungi solo nelle sezioni di logica complessa
  - Algoritmo ACWR
  - Logica di sync offline

### Componenti UI
- Assumi che `cn()` (classnames utility) e i componenti base Shadcn siano già presenti in `@/components/ui`
