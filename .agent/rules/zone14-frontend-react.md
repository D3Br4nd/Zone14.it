---
trigger: glob
globs: **/*.tsx, **/*.jsx
---

# Zone14 - Frontend React Rules (Glob: **/*.tsx, **/*.jsx)

Questa regola si applica automaticamente a tutti i file React/TypeScript del progetto.

---

## ⚛️ React 19 Standards

### Component Structure
```tsx
// resources/js/Pages/Players/Show.tsx
import { Head, usePage } from '@inertiajs/react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { Player, Team } from '@/types';

interface Props {
  player: Player;
  team: Team;
  stats: PlayerStats; // Deferred prop
}

export default function PlayerShow({ player, team, stats }: Props) {
  return (
    <>
      <Head title={`${player.firstName} ${player.lastName}`} />
      
      <div className="container mx-auto py-8">
        <Card>
          <CardHeader>
            <CardTitle>{player.fullName}</CardTitle>
            <Badge variant={player.isActive ? 'success' : 'secondary'}>
              {player.isActive ? 'Active' : 'Inactive'}
            </Badge>
          </CardHeader>
          
          <CardContent>
            <PlayerStatsSection stats={stats} />
          </CardContent>
        </Card>
      </div>
    </>
  );
}
```

---

## 📝 Forms & Actions (NO useState manual)

### Standard Form Pattern
```tsx
import { useForm } from '@inertiajs/react';
import { FormEventHandler } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

interface CreatePlayerFormProps {
  teamId: string;
}

export default function CreatePlayerForm({ teamId }: CreatePlayerFormProps) {
  const { data, setData, post, processing, errors, reset } = useForm({
    firstName: '',
    lastName: '',
    birthDate: '',
    position: '',
    teamId,
  });

  const submit: FormEventHandler = (e) => {
    e.preventDefault();
    post(route('players.store'), {
      onSuccess: () => reset(),
      onError: () => {
        // Error handling automatico via errors object
      },
    });
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      <div>
        <Label htmlFor="firstName">First Name</Label>
        <Input
          id="firstName"
          value={data.firstName}
          onChange={(e) => setData('firstName', e.target.value)}
          disabled={processing}
          aria-invalid={!!errors.firstName}
          aria-describedby={errors.firstName ? 'firstName-error' : undefined}
        />
        {errors.firstName && (
          <p id="firstName-error" className="text-sm text-destructive mt-1">
            {errors.firstName}
          </p>
        )}
      </div>

      <div>
        <Label htmlFor="lastName">Last Name</Label>
        <Input
          id="lastName"
          value={data.lastName}
          onChange={(e) => setData('lastName', e.target.value)}
          disabled={processing}
        />
        {errors.lastName && (
          <p className="text-sm text-destructive mt-1">{errors.lastName}</p>
        )}
      </div>

      <div>
        <Label htmlFor="birthDate">Birth Date</Label>
        <Input
          id="birthDate"
          type="date"
          value={data.birthDate}
          onChange={(e) => setData('birthDate', e.target.value)}
          disabled={processing}
        />
        {errors.birthDate && (
          <p className="text-sm text-destructive mt-1">{errors.birthDate}</p>
        )}
      </div>

      <Button type="submit" disabled={processing}>
        {processing ? 'Creating...' : 'Create Player'}
      </Button>
    </form>
  );
}
```

### React 19 Actions (Complex Forms)
```tsx
import { useActionState } from 'react';
import { router } from '@inertiajs/react';

export default function PlayerRegistrationForm() {
  const [state, formAction, isPending] = useActionState(
    async (prevState: any, formData: FormData) => {
      const data = Object.fromEntries(formData);
      
      // Validation client-side
      if (!data.email || !data.firstName) {
        return { errors: { email: 'Email required', firstName: 'First name required' } };
      }
      
      try {
        await router.post('/players', data, {
          preserveScroll: true,
          onSuccess: () => {
            // Reset handled by router
          },
        });
        return { success: true };
      } catch (error) {
        return { errors: { submit: 'Registration failed' } };
      }
    },
    null
  );

  return (
    <form action={formAction}>
      <input name="email" type="email" disabled={isPending} />
      {state?.errors?.email && <span>{state.errors.email}</span>}
      
      <input name="firstName" disabled={isPending} />
      {state?.errors?.firstName && <span>{state.errors.firstName}</span>}
      
      <button type="submit" disabled={isPending}>
        {isPending ? 'Registering...' : 'Register'}
      </button>
    </form>
  );
}
```

---

## 🔄 Deferred Props & Polling

### Heavy Data Loading
```tsx
import { Deferred } from '@inertiajs/react';
import { Skeleton } from '@/components/ui/skeleton';
import type { TeamStatistics } from '@/types';

interface Props {
  teamId: string;
  statistics: TeamStatistics; // Marcato come Deferred in controller
}

export default function TeamDashboard({ teamId, statistics }: Props) {
  return (
    <div className="grid grid-cols-3 gap-4">
      <Deferred data="statistics" fallback={<StatisticsSkeleton />}>
        {(stats) => (
          <>
            <StatCard title="Goals Scored" value={stats.goalsScored} />
            <StatCard title="Goals Conceded" value={stats.goalsConceded} />
            <StatCard title="Win Rate" value={`${stats.winRate}%`} />
          </>
        )}
      </Deferred>
    </div>
  );
}

function StatisticsSkeleton() {
  return (
    <>
      <Skeleton className="h-32 w-full" />
      <Skeleton className="h-32 w-full" />
      <Skeleton className="h-32 w-full" />
    </>
  );
}
```

### Live Match Updates
```tsx
import { usePoll } from '@inertiajs/react';
import type { Match, MatchEvent } from '@/types';

interface Props {
  match: Match;
  events: MatchEvent[];
}

export default function LiveMatchCenter({ match, events }: Props) {
  // Poll ogni 3 secondi per aggiornare score ed eventi
  usePoll(3000, {
    only: ['match.homeScore', 'match.awayScore', 'events'],
    keepAliveProp: 'match.status',
    keepAliveValue: 'in_progress',
  });

  return (
    <div className="live-match">
      <div className="scoreboard">
        <TeamScore team={match.homeTeam} score={match.homeScore} />
        <span className="text-2xl font-bold">-</span>
        <TeamScore team={match.awayTeam} score={match.awayScore} />
      </div>

      <div className="events-timeline mt-8">
        {events.map((event) => (
          <MatchEventCard key={event.id} event={event} />
        ))}
      </div>
    </div>
  );
}
```

---

## 🎨 Shadcn UI Integration

### Component Import Pattern
```tsx
// ❌ NON fare import relativi complessi
import { Button } from '../../../components/ui/button';

// ✅ Usa path alias configurato
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { useToast } from '@/hooks/use-toast';
```

### Custom Variants (nel file componente)
```tsx
// resources/js/components/ui/button.tsx
import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent',
        // Custom variant per Zone14
        sport: 'bg-sport-primary text-white hover:bg-sport-primary/80',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
```

---

## 🗂️ TypeScript Types & Interfaces

### Inertia Props Types
```typescript
// resources/js/types/index.ts

// Base Models
export interface Player {
  id: string;
  firstName: string;
  lastName: string;
  fullName: string; // Property hook from backend
  birthDate: string;
  position: string;
  jerseyNumber: number;
  isActive: boolean;
  teamId: string;
  metadata: PlayerMetadata;
  createdAt: string;
  updatedAt: string;
}

export interface PlayerMetadata {
  height?: number;
  weight?: number;
  preferredFoot?: 'left' | 'right' | 'both';
  skills?: string[];
}

export interface Team {
  id: string;
  name: string;
  logoUrl: string | null;
  foundedYear: number;
  stadium: string;
}

export interface Match {
  id: string;
  homeTeamId: string;
  awayTeamId: string;
  homeTeam: Team;
  awayTeam: Team;
  homeScore: number;
  awayScore: number;
  status: 'scheduled' | 'in_progress' | 'finished' | 'cancelled';
  kickoffAt: string;
  endedAt: string | null;
}

// Page Props (generici Inertia)
export interface PageProps {
  auth: {
    user: User;
  };
  ziggy: {
    location: string;
    query: Record<string, any>;
  };
  flash: {
    success?: string;
    error?: string;
    warning?: string;
  };
}

// Estensioni per pagine specifiche
export interface PlayersIndexProps extends PageProps {
  players: Player[];
  filters: {
    search?: string;
    position?: string;
    isActive?: boolean;
  };
  pagination: PaginationMeta;
}

export interface PaginationMeta {
  currentPage: number;
  lastPage: number;
  perPage: number;
  total: number;
}
```

### Shared Type Guards
```typescript
// resources/js/lib/type-guards.ts

export function isMatchInProgress(match: Match): boolean {
  return match.status === 'in_progress';
}

export function isPlayerEligible(player: Player): boolean {
  return player.isActive && player.metadata.medicalClearance === true;
}

export function hasPermission(user: User, permission: string): boolean {
  return user.permissions.includes(permission);
}
```

---

## 📱 Offline-First (Dexie.js)

### Database Setup
```typescript
// resources/js/lib/db.ts
import Dexie, { type EntityTable } from 'dexie';

interface MatchEvent {
  id: string;
  matchId: string;
  playerId: string;
  type: 'goal' | 'assist' | 'card' | 'substitution';
  minute: number;
  synced: boolean;
  createdAt: Date;
}

const db = new Dexie('Zone14Database') as Dexie & {
  matchEvents: EntityTable<MatchEvent, 'id'>;
};

db.version(1).stores({
  matchEvents: '++id, matchId, synced, createdAt',
});

export { db };
export type { MatchEvent };
```

### Sync Queue Pattern
```typescript
// resources/js/lib/sync-queue.ts
import { router } from '@inertiajs/react';
import { db } from './db';

export async function recordMatchEvent(
  matchId: string,
  eventData: Omit<MatchEvent, 'id' | 'synced' | 'createdAt'>
) {
  // 1. Write to IndexedDB immediately
  const eventId = await db.matchEvents.add({
    ...eventData,
    matchId,
    synced: false,
    createdAt: new Date(),
  });

  // 2. Update UI optimistically
  // (React query mutation or state update)

  // 3. Background sync
  syncMatchEven