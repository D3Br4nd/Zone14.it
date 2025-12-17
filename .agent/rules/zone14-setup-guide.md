---
trigger: always_on
---

# Zone14 - Guida Configurazione Rules per Antigravity

## 📁 Struttura Files Creati

```
zone14-rules/
├── zone14-always-on.md          # Rule generale (Always On)
├── zone14-backend-php.md         # Backend PHP (Glob: **/*.php)
├── zone14-frontend-react.md      # Frontend React (Glob: **/*.tsx, **/*.jsx)
└── zone14-database.md            # Database (Glob: database/**/*.php)
```

---

## 🚀 Setup in Antigravity

### 1. Creare Global Rule (Always On)

**Percorso**: `~/.gemini/GEMINI.md` (oppure tramite UI: Customizations → Rules → + Global)

**Contenuto**: Copia il file `zone14-always-on.md`

**Activation**: **Always On**

**Scopo**: Fornisce il contesto architetturale generale, stack tecnologico, e vincoli critici che devono essere sempre presenti (multi-tenancy, UUIDv7, PgBouncer, offline-first, PBAC).

---

### 2. Creare Workspace Rules (Glob)

**Percorso**: `.agent/rules/` nella root del workspace Zone14

#### Rule: Backend PHP

**File**: `.agent/rules/backend-php.md`

**Contenuto**: Copia il file `zone14-backend-php.md`

**Activation**: **Glob**
```
**/*.php
```

**Escludi Glob** (opzionale, per evitare vendor):
```
!vendor/**
!node_modules/**
```

**Scopo**: Pattern PHP 8.4, Property Hooks, Action Classes, Policy, DTO, testing.

---

#### Rule: Frontend React

**File**: `.agent/rules/frontend-react.md`

**Contenuto**: Copia il file `zone14-frontend-react.md`

**Activation**: **Glob**
```
**/*.tsx
**/*.jsx
```

**Escludi Glob**:
```
!node_modules/**
!vendor/**
```

**Scopo**: React 19, Inertia.js 2.0, Shadcn UI, TypeScript, Offline-first con Dexie.js.

---

#### Rule: Database

**File**: `.agent/rules/database.md`

**Contenuto**: Copia il file `zone14-database.md`

**Activation**: **Glob**
```
database/**/*.php
```

**Scopo**: Migrazioni, UUIDv7, indexing, zero-downtime, multi-tenancy, factories, seeders.

---

## 📊 Distribuzione Token Estimata

| Rule | Caratteri | Token Stimati | Activation |
|------|-----------|---------------|------------|
| Always On | ~11.5k | ~3,500 | Always |
| Backend PHP | ~11k | ~3,300 | Glob `*.php` |
| Frontend React | ~11k | ~3,300 | Glob `*.tsx, *.jsx` |
| Database | ~10k | ~3,000 | Glob `database/**` |
| **TOTALE** | **~43.5k** | **~13,100** | Context-aware |

**Ottimizzazione**: Invece di caricare sempre 13k token, Antigravity caricherà:
- Always On (3.5k) → **sempre**
- Backend PHP (3.3k) → **solo quando lavori su `.php`**
- Frontend React (3.3k) → **solo quando lavori su `.tsx/.jsx`**
- Database (3k) → **solo quando lavori in `database/`**

**Esempio scenario reale**:
- Lavori su `app/Actions/CalculateAcwrAction.php` → carica Always On + Backend PHP = ~6.8k token
- Lavori su `resources/js/Pages/Dashboard.tsx` → carica Always On + Frontend React = ~6.8k token
- Lavori su `database/migrations/2024_create_players.php` → carica Always On + Database = ~6.5k token

---

## 🎯 Best Practices per Usage

### 1. Evita Ridondanza
Le 4 rules sono **complementari**, non ridondanti:
- Always On = architettura generale, stack, vincoli critici
- Backend = pattern PHP concreti, codice specifico
- Frontend = pattern React concreti, UI components
- Database = schema design, migrazioni

### 2. Aggiornamenti
Quando aggiorni tecnologie (es. Laravel 13, React 20):
1. Aggiorna Always On per nuove feature generali
2. Aggiorna le specifiche rules per nuovi pattern

### 3. Testing
Dopo setup, testa con prompt specifici:
```
"Create a new PlayerController with PBAC authorization"
→ Dovrebbe usare Always On + Backend PHP

"Build a LiveMatchCenter component with polling"
→ Dovrebbe usare Always On + Frontend React

"Create migration for workload tracking with ACWR support"
→ Dovrebbe usare Always On + Database
```

---

## 🔧 Configurazione Avanzata (Opzionale)

### Model Decision Rules

Se vuoi che alcune regole si attivino solo per contesti specifici (invece di glob):

**Esempio: Rule per API Integration**
```markdown
# Zone14 - API Integration Rules

## When to activate
Activate when working on:
- Stripe Connect OAuth
- Webhook handling
- External API integrations
- OAuth2 token management

## Content
[... specifics ...]
```

**Activation**: **Model Decision**

**Description**: "Activate when working on external API integrations, webhooks, or OAuth flows"

---

### @ Mentions per Cross-Reference

Puoi referenziare files nel workspace:

```markdown
# Example

See the actual implementation in @app/Actions/CalculateAcwrAction.php

For frontend integration, check @resources/js/Pages/Analytics/Dashboard.tsx
```

Antigravity risolverà i path e includerà il contenuto se necessario.

---

## 🚨 Troubleshooting

### "Rule non si attiva"
- **Causa**: Glob pattern errato
- **Fix**: Verifica che il file corrente matchi il pattern. Usa `**/*.php` non `*.php`

### "Troppo contesto, timeout"
- **Causa**: Tutte le rules attive simultaneamente
- **Fix**: Assicurati che Backend/Frontend/Database usino Glob, non Always On

### "AI ignora le regole"
- **Causa**: Prompt dell'utente sovrascrive
- **Fix**: Inizia il prompt con "Following Zone14 standards..." per rinforzare

---

## 📈 Metriche di Successo

Dopo 1 settimana di usage, verifica:
- [ ] Nessun ID auto-increment generato
- [ ] Nessun getter/setter tradizionale PHP
- [ ] Form React usano `useForm` (no `useState` manuale)
- [ ] Migrazioni hanno `CONCURRENTLY` per indici
- [ ] Policy usate invece di check su ruoli
- [ ] Componenti Shadcn installati via CLI (no copy/paste)

---

## 🔄 Aggiornamento Rules

**Frequency**: Trimestrale o ad ogni major release tecnologica

**Processo**:
1. Identifica breaking changes (es. Laravel 13 depreca X)
2. Aggiorna la rule specifica (non tutte)
3. Testa con task comuni
4. Deploy in `.agent/rules/` o `~/.gemini/`
5. Notifica team

**Version Control**:
```bash
# Committa le rules nel repo
git add .agent/rules/
git commit -m "chore: update Zone14 rules to v3.2"
```

---

## 📚 Risorse Addizionali

### Documentazione Ufficiale
- Laravel 12: https://laravel.com/docs/12.x
- React 19: https://react.dev
- Inertia.js 2.0: https://inertiajs.com/docs/v2
- Shadcn UI: https://ui.shadcn.com
- stancl/tenancy: https://tenancyforlaravel.com/docs/v3

### MCP Integration
Configura anche `.cursor/mcp.json` per Shadcn:
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

Questo permette all'AI di interrogare i componenti UI reali.

---

**Setup completato!** 🎉

Le rules sono ora pronte per essere integrate in Antigravity con un caricamento intelligente basato sul contesto.
