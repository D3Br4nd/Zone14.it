---
trigger: glob
globs: **/*.tsx, **/*.jsx
---

# Zone14 - Frontend React Rules (Glob: **/*.tsx, **/*.jsx)

## ⚛️ Component Structure

```tsx
import { Head } from '@inertiajs/react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import type { Player, Team } from '@/types';

interface Props {
  player: Player;
  team: Team;
  stats: PlayerStats; // Deferred
}

export default function PlayerShow({ player, team, stats }: Props) {
  return (
    <>
      <Head title={player.fullName} />
      <Card>
        <CardHeader>
          <CardTitle>{player.fullName}</CardTitle>
        </CardHeader>
        <CardContent>
          <PlayerStatsSection stats={stats} />
        </CardContent>
      </Card>
    </>
  );
}
```

---

## 📝 Forms (NO useState)

```tsx
import { useForm } from '@inertiajs/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export default function CreatePlayerForm({ teamId }: Props) {
  const { data, setData, post, processing, errors } = useForm({
    firstName: '',
    lastName: '',
    teamId,
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    post(route('players.store'));
  };

  return (
    <form onSubmit={submit}>
      <Input
        value={data.firstName}
        onChange={(e) => setData('firstName', e.target.value)}
        disabled={processing}
      />
      {errors.firstName && <span>{errors.firstName}</span>}
      <Button type="submit" disabled={processing}>Create</Button>
    </form>
  );
}
```

---

## 🔄 Deferred Props

```tsx
import { Deferred } from '@inertiajs/react';
import { Skeleton } from '@/components/ui/skeleton';

interface Props {
  teamId: string;
  statistics: TeamStatistics; // Marked as Deferred in controller
}

export default function Dashboard({ statistics }: Props) {
  return (
    <Deferred data="statistics" fallback={<Skeleton className="h-32" />}>
      {(stats) => (
        <div>
          <StatCard title="Goals" value={stats.goals} />
          <StatCard title="Wins" value={stats.wins} />
        </div>
      )}
    </Deferred>
  );
}
```

---

## 📡 Live Updates (Polling)

```tsx
import { usePoll } from '@inertiajs/react';

interface Props {
  match: Match;
  events: MatchEvent[];
}

export default function LiveMatch({ match, events }: Props) {
  // Poll every 3 seconds
  usePoll(3000, {
    only: ['match.homeScore', 'match.awayScore', 'events'],
  });

  return (
    <div>
      <Scoreboard match={match} />
      <EventsList events={events} />
    </div>
  );
}
```

---

## 🎨 Shadcn UI

```tsx
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

// Custom variant (in component file)
const buttonVariants = cva('...', {
  variants: {
    variant: {
      default: 'bg-primary',
      sport: 'bg-sport-primary text-white', // Custom
    },
  },
});
```

---

## 🗂️ TypeScript Types

```typescript
export interface Player {
  id: string;
  firstName: string;
  lastName: string;
  fullName: string; // Property hook
  birthDate: string;
  position: string;
  isActive: boolean;
  teamId: string;
  metadata: PlayerMetadata;
}

export interface PlayerMetadata {
  height?: number;
  weight?: number;
  preferredFoot?: 'left' | 'right' | 'both';
}

export interface PageProps {
  auth: { user: User };
  flash: {
    success?: string;
    error?: string;
  };
}
```

---

## 📱 Offline-First (Dexie.js)

### Database Setup
```typescript
import Dexie, { type EntityTable } from 'dexie';

interface MatchEvent {
  id: string;
  matchId: string;
  type: 'goal' | 'card';
  synced: boolean;
  createdAt: Date;
}

const db = new Dexie('Zone14') as Dexie & {
  matchEvents: EntityTable<MatchEvent, 'id'>;
};

db.version(1).stores({
  matchEvents: '++id, matchId, synced, createdAt',
});

export { db };
```

### Sync Queue
```typescript
import { router } from '@inertiajs/react';
import { db } from './db';

export async function recordEvent(matchId: string, eventData: any) {
  // 1. Write to IndexedDB
  const id = await db.matchEvents.add({
    ...eventData,
    matchId,
    synced: false,
    createdAt: new Date(),
  });

  // 2. Background sync
  syncEvent(id);
}

async function syncEvent(id: string) {
  const event = await db.matchEvents.get(id);
  if (!event || event.synced) return;

  try {
    await router.post(`/matches/${event.matchId}/events`, event, {
      onSuccess: async () => {
        await db.matchEvents.update(id, { synced: true });
      },
    });
  } catch {
    setTimeout(() => syncEvent(id), 5000); // Retry
  }
}
```

### Component
```tsx
import { db } from '@/lib/db';
import { recordEvent } from '@/lib/sync-queue';

export default function MatchLogger({ matchId }: Props) {
  const handleGoal = async (playerId: string) => {
    await recordEvent(matchId, {
      playerId,
      type: 'goal',
      minute: getCurrentMinute(),
    });
  };

  return <Button onClick={() => handleGoal('player-123')}>Goal</Button>;
}
```

---

## 🎯 Performance

### NO useMemo/useCallback (React 19)
```tsx
// ❌ Not needed
const value = useMemo(() => expensive(a, b), [a, b]);

// ✅ Compiler handles it
const value = expensive(a, b);
```

### Lazy Loading
```tsx
import { lazy, Suspense } from 'react';

const Chart = lazy(() => import('@/components/Chart'));

<Suspense fallback={<Skeleton />}>
  <Chart data={data} />
</Suspense>
```

---

## ♿ Accessibility

```tsx
<Button
  aria-label="Add player"
  aria-pressed={isExpanded}
  aria-controls="player-form"
>
  <PlusIcon aria-hidden="true" />
  Add
</Button>

<ul role="listbox" aria-label="Players">
  <li role="option" tabIndex={0} onKeyDown={handleKey}>
    Player Name
  </li>
</ul>
```

---

## 🧪 Testing

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

test('submits form', async () => {
  const user = userEvent.setup();
  render(<CreatePlayerForm />);

  await user.type(screen.getByLabelText(/name/i), 'John');
  await user.click(screen.getByRole('button', { name: /create/i }));

  expect(router.post).toHaveBeenCalled();
});
```

---

## 🚫 Anti-Patterns

❌ **NO**: `useState` for forms, `useMemo`/`useCallback` manual, `tailwind.config.js`, direct API calls
✅ **YES**: `useForm` from Inertia, React 19 compiler, CSS `@theme`, Dexie → sync queue

---

**Caratteri: ~4,200** | **Target**: React 19 + Inertia 2.0 + TypeScript + Shadcn