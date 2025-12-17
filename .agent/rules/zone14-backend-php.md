---
trigger: glob
globs: **/*.php
---

# Zone14 - Backend PHP Rules (Glob: **/*.php)

## 🏗️ Model Template

```php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Ramsey\Uuid\Uuid;

class Player extends Model
{
    use HasUuids;
    
    protected $keyType = 'string';
    public $incrementing = false;
    
    public function newUniqueId(): string
    {
        return Uuid::uuid7()->toString();
    }
    
    // Property Hooks (NO getXAttribute)
    public string $fullName {
        get => $this->firstName . ' ' . $this->lastName;
    }
    
    public private(set) string $tenantId;
    
    protected $casts = [
        'birth_date' => 'date',
        'is_active' => 'boolean',
        'metadata' => 'array',
    ];
}
```

---

## 🎯 Action Classes

```php
namespace App\Actions\Players;

class CalculatePlayerStatsAction
{
    public function execute(Player $player, ?Carbon $startDate = null): PlayerStatsDTO
    {
        $startDate ??= now()->subMonths(3);
        
        return new PlayerStatsDTO(
            goals: $player->events()->where('type', 'goal')->count(),
            assists: $player->events()->where('type', 'assist')->count(),
            minutes: $this->calculateMinutes($player, $startDate),
        );
    }
}
```

---

## 📋 DTO Pattern

```php
namespace App\DTOs;

readonly class MatchStatsDTO
{
    public function __construct(
        public string $matchId,
        public int $homeGoals,
        public int $awayGoals,
        /** @var array<EventDTO> */
        public array $events,
    ) {}
    
    public static function fromMatch(Match $match): self
    {
        return new self(
            matchId: $match->id,
            homeGoals: $match->home_score,
            awayGoals: $match->away_score,
            events: $match->events->map(fn($e) => EventDTO::fromModel($e))->toArray(),
        );
    }
}
```

---

## 🎮 Controller Pattern

```php
class MatchController extends Controller
{
    public function __construct(
        private readonly GenerateMatchReportAction $generateReport
    ) {}
    
    public function show(Match $match): Response
    {
        $this->authorize('view', $match);
        
        return Inertia::render('Match/Show', [
            'match' => $match->load(['homeTeam', 'awayTeam']),
            'statistics' => Inertia::defer(
                fn() => $this->generateReport->execute($match)
            ),
        ]);
    }
}
```

---

## 🔐 Policy Examples

```php
class MatchPolicy
{
    public function view(User $user, Match $match): bool
    {
        if ($user->hasRole('admin')) return true;
        
        if ($user->hasRole('coach')) {
            return $user->team_id === $match->home_team_id
                || $user->team_id === $match->away_team_id;
        }
        
        return false;
    }
    
    public function viewMedicalData(User $user, Player $player): bool
    {
        if ($user->hasRole('team_doctor')) {
            return $user->team_id === $player->team_id;
        }
        
        return $user->id === $player->user_id;
    }
}
```

---

## 🗄️ Query Optimization

```php
// ✅ Eager loading
$players = Player::with('team')->get();

// ✅ Chunking
Player::chunk(200, function ($players) {
    // Process
});

// ✅ JSON queries
$players = Player::whereJsonContains('metadata->skills', 'goalkeeper')->get();
```

---

## 📅 Job Pattern

```php
class GenerateMatchReportJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;
    
    public int $tries = 3;
    public int $timeout = 120;
    
    public function __construct(public Match $match) {}
    
    public function handle(GenerateMatchReportAction $action): void
    {
        $report = $action->execute($this->match);
        
        $this->match->update([
            'report_data' => $report->toArray(),
            'report_generated_at' => now(),
        ]);
    }
}
```

---

## 🔄 Multi-Tenant Specifics

### Central Migration
```php
// database/migrations/2024_01_01_create_tenants_table.php
Schema::create('tenants', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->string('plan_tier');
    $table->string('owner_email')->unique();
    $table->timestamp('trial_ends_at')->nullable();
    $table->timestamps();
});
```

### Tenant Migration
```php
// database/migrations/tenant/2024_01_01_create_players_table.php
Schema::create('players', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('team_id')->constrained()->cascadeOnDelete();
    $table->string('first_name');
    $table->string('last_name');
    $table->date('birth_date');
    $table->json('metadata')->nullable();
    $table->timestamps();
    
    $table->index('team_id');
});
```

---

## 🧪 Testing

```php
test('coach can view own team match', function () {
    $coach = User::factory()->coach()->create();
    $match = Match::factory()->create(['home_team_id' => $coach->team_id]);
    
    actingAs($coach)
        ->get(route('matches.show', $match))
        ->assertOk();
});
```

---

## 📈 ACWR Calculation

```php
class CalculateAcwrAction
{
    public function execute(Player $player, Carbon $date): float
    {
        $acuteLoad = Workload::where('player_id', $player->id)
            ->whereBetween('date', [$date->copy()->subDays(7), $date])
            ->sum(DB::raw('duration * rpe'));
        
        $chronicLoad = Workload::where('player_id', $player->id)
            ->whereBetween('date', [$date->copy()->subDays(28), $date])
            ->sum(DB::raw('duration * rpe')) / 4;
        
        return $chronicLoad > 0 ? $acuteLoad / $chronicLoad : 0;
    }
}
```

---

## 🚫 Anti-Patterns

❌ **NO**: `getXAttribute()`, auto-increment IDs, role checks (`if $user->role`), logic in controllers, `mixed` types
✅ **YES**: Property Hooks, UUIDv7, Policy checks, Action classes, strict types

---

**Caratteri: ~3,800** | **Target**: PHP 8.4 + Laravel 12 + PostgreSQL 18