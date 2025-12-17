---
trigger: glob
globs: **/*.php
---

# Zone14 - Backend PHP Rules (Glob: **/*.php)

Questa regola si applica automaticamente a tutti i file PHP del progetto.

---

## 🏗️ Struttura Modelli Eloquent

### Template Base Model
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
    
    // UUID v7 forzato
    public function newUniqueId(): string
    {
        return Uuid::uuid7()->toString();
    }
    
    // Property Hooks per logica domain
    public string $fullName {
        get => $this->firstName . ' ' . $this->lastName;
    }
    
    public private(set) string $tenantId; // Leggibile, modificabile solo internamente
    
    protected $casts = [
        'birth_date' => 'date',
        'is_active' => 'boolean',
        'metadata' => 'array',
    ];
}
```

### Relazioni Multi-Tenant
**SEMPRE** usare scope globale per tenant (gestito da stancl/tenancy automaticamente).

```php
// Relazioni standard - NO bisogno di tenant_id manuale
public function team(): BelongsTo
{
    return $this->belongsTo(Team::class);
}

public function injuries(): HasMany
{
    return $this->hasMany(Injury::class);
}
```

---

## 🎯 Action Classes Pattern

### Struttura Directory
```
app/
├── Actions/
│   ├── Players/
│   │   ├── CreatePlayerAction.php
│   │   ├── UpdatePlayerStatsAction.php
│   │   └── CalculatePlayerWorkloadAction.php
│   ├── Matches/
│   │   ├── RecordMatchEventAction.php
│   │   └── GenerateMatchReportAction.php
│   └── Analytics/
│       ├── CalculateAcwrAction.php
│       └── GenerateInjuryPredictionAction.php
```

### Template Action
```php
namespace App\Actions\Players;

use App\Models\Player;
use App\DTOs\PlayerStatsDTO;

class CalculatePlayerStatsAction
{
    public function execute(Player $player, ?Carbon $startDate = null): PlayerStatsDTO
    {
        $startDate ??= now()->subMonths(3);
        
        // Logica complessa qui
        $goals = $player->events()
            ->where('type', 'goal')
            ->where('date', '>=', $startDate)
            ->count();
        
        $assists = $player->events()
            ->where('type', 'assist')
            ->where('date', '>=', $startDate)
            ->count();
        
        return new PlayerStatsDTO(
            goals: $goals,
            assists: $assists,
            minutes: $this->calculateMinutesPlayed($player, $startDate),
        );
    }
    
    private function calculateMinutesPlayed(Player $player, Carbon $startDate): int
    {
        // Logica privata helper
    }
}
```

---

## 📋 Data Transfer Objects (DTO)

### Standard DTO
```php
namespace App\DTOs;

readonly class MatchStatsDTO
{
    public function __construct(
        public string $matchId,
        public int $homeGoals,
        public int $awayGoals,
        public float $homePossession,
        public float $awayPossession,
        /** @var array<EventDTO> */
        public array $events,
        public ?string $mvpPlayerId = null,
    ) {}
    
    // Factory methods se necessari
    public static function fromMatch(Match $match): self
    {
        return new self(
            matchId: $match->id,
            homeGoals: $match->home_score,
            awayGoals: $match->away_score,
            homePossession: $match->calculatePossession('home'),
            awayPossession: $match->calculatePossession('away'),
            events: $match->events->map(fn($e) => EventDTO::fromModel($e))->toArray(),
            mvpPlayerId: $match->mvp_id,
        );
    }
    
    // Serializzazione per Inertia
    public function toArray(): array
    {
        return [
            'matchId' => $this->matchId,
            'homeGoals' => $this->homeGoals,
            'awayGoals' => $this->awayGoals,
            'homePossession' => $this->homePossession,
            'awayPossession' => $this->awayPossession,
            'events' => array_map(fn($e) => $e->toArray(), $this->events),
            'mvpPlayerId' => $this->mvpPlayerId,
        ];
    }
}
```

---

## 🎮 Controller Pattern

### Template Controller
```php
namespace App\Http\Controllers;

use App\Models\Match;
use App\Actions\Matches\GenerateMatchReportAction;
use Inertia\Inertia;
use Inertia\Response;

class MatchController extends Controller
{
    public function __construct(
        private readonly GenerateMatchReportAction $generateReport
    ) {}
    
    public function show(Match $match): Response
    {
        // Policy check automatico (definito in AuthServiceProvider)
        $this->authorize('view', $match);
        
        return Inertia::render('Match/Show', [
            'match' => $match->load(['homeTeam', 'awayTeam']),
            'events' => $match->events()->orderBy('minute')->get(),
            // Deferred per dati pesanti
            'statistics' => Inertia::defer(
                fn() => $this->generateReport->execute($match)
            ),
        ]);
    }
    
    public function store(StoreMatchRequest $request): RedirectResponse
    {
        $match = app(CreateMatchAction::class)->execute(
            $request->validated()
        );
        
        return redirect()->route('matches.show', $match)
            ->with('success', 'Match created successfully');
    }
}
```

---

## 🔐 Policy Examples

### Template Policy
```php
namespace App\Policies;

use App\Models\User;
use App\Models\Match;

class MatchPolicy
{
    // Visibilità match (team coach può vedere solo proprie partite)
    public function view(User $user, Match $match): bool
    {
        if ($user->hasRole('admin')) {
            return true;
        }
        
        if ($user->hasRole('coach')) {
            return $user->team_id === $match->home_team_id
                || $user->team_id === $match->away_team_id;
        }
        
        return false;
    }
    
    // Editing eventi partita (solo durante finestra temporale)
    public function update(User $user, Match $match): bool
    {
        if (!$user->can('view', $match)) {
            return false;
        }
        
        // Finestra edit: durante partita + 2 ore dopo
        $editDeadline = $match->ended_at?->addHours(2);
        
        return $match->status === 'in_progress'
            || ($editDeadline && now()->lessThan($editDeadline));
    }
    
    // Policy dinamica ABAC-style
    public function viewMedicalData(User $user, Player $player): bool
    {
        // Medico del team può vedere tutti i giocatori del team
        if ($user->hasRole('team_doctor')) {
            return $user->team_id === $player->team_id;
        }
        
        // Admin federale può vedere tutto
        if ($user->hasRole('federation_admin')) {
            return true;
        }
        
        // Giocatore può vedere solo i propri dati
        return $user->id === $player->user_id;
    }
}
```

---

## 🗄️ Query Optimization

### N+1 Prevention
```php
// ❌ BAD
$players = Player::all();
foreach ($players as $player) {
    echo $player->team->name; // N+1 query!
}

// ✅ GOOD
$players = Player::with('team')->get();
foreach ($players as $player) {
    echo $player->team->name; // 1 query totale
}
```

### Chunking per Dataset Large
```php
// Per export o calcoli su migliaia di record
Player::query()
    ->where('team_id', $teamId)
    ->chunk(200, function ($players) {
        foreach ($players as $player) {
            // Process
        }
    });
```

### PostgreSQL JSON Queries
```php
// Query su colonna JSON (metadata)
$players = Player::query()
    ->whereJsonContains('metadata->skills', 'goalkeeper')
    ->get();

// Ordinamento per campo JSON
$players = Player::query()
    ->orderBy('metadata->rating', 'desc')
    ->get();
```

---

## 📅 Job & Queue Pattern

### Template Job
```php
namespace App\Jobs;

use App\Models\Match;
use App\Actions\Matches\GenerateMatchReportAction;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class GenerateMatchReportJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;
    
    public int $tries = 3;
    public int $timeout = 120;
    
    public function __construct(
        public Match $match
    ) {}
    
    public function handle(GenerateMatchReportAction $action): void
    {
        $report = $action->execute($this->match);
        
        // Salva report generato
        $this->match->update([
            'report_data' => $report->toArray(),
            'report_generated_at' => now(),
        ]);
    }
    
    public function failed(\Throwable $exception): void
    {
        \Log::error('Match report generation failed', [
            'match_id' => $this->match->id,
            'error' => $exception->getMessage(),
        ]);
    }
}
```

### Dispatch Pattern
```php
// Immediato (sincrono)
app(GenerateMatchReportAction::class)->execute($match);

// Asincrono (queue)
GenerateMatchReportJob::dispatch($match);

// Delayed
GenerateMatchReportJob::dispatch($match)->delay(now()->addMinutes(5));

// Su queue specifica
GenerateMatchReportJob::dispatch($match)->onQueue('analytics');
```

---

## 🧪 Testing Standards

### Feature Test Template
```php
namespace Tests\Feature;

use Tests\TestCase;
use App\Models\{User, Match, Player};
use Illuminate\Foundation\Testing\RefreshDatabase;

class MatchControllerTest extends TestCase
{
    use RefreshDatabase;
    
    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(TenantSeeder::class); // Setup tenant
    }
    
    public function test_coach_can_view_own_team_match(): void
    {
        $coach = User::factory()->coach()->create();
        $match = Match::factory()->create(['home_team_id' => $coach->team_id]);
        
        $response = $this->actingAs($coach)
            ->get(route('matches.show', $match));
        
        $response->assertOk()
            ->assertInertia(fn($page) => 
                $page->component('Match/Show')
                    ->has('match')
                    ->where('match.id', $match->id)
            );
    }
    
    public function test_coach_cannot_view_other_team_match(): void
    {
        $coach = User::factory()->coach()->create();
        $match = Match::factory()->create(); // Team diverso
        
        $response = $this->actingAs($coach)
            ->get(route('matches.show', $match));
        
        $response->assertForbidden();
    }
}
```

### Unit Test Template (Action)
```php
namespace Tests\Unit\Actions;

use Tests\TestCase;
use App\Actions\Analytics\CalculateAcwrAction;
use App\Models\{Player, Workload};

class CalculateAcwrActionTest extends TestCase
{
    public function test_calculates_correct_acwr(): void
    {
        $player = Player::factory()->create();
        
        // Setup workload data
        Workload::factory()->create([
            'player_id' => $player->id,
            'date' => now()->subDays(3),
            'rpe' => 7,
            'duration' => 90,
        ]);
        
        $action = new CalculateAcwrAction();
        $acwr = $action->execute($player, now());
        
        $this->assertIsFloat($acwr);
        $this->assertGreaterThan(0, $acwr);
        $this->assertLessThan(3, $acwr); // Sanity check
    }
}
```

---

## 🔄 Multi-Tenant Specifics

### Central vs Tenant Migrations
```php
// database/migrations/2024_01_01_create_tenants_table.php (CENTRAL)
public function up()
{
    Schema::create('tenants', function (Blueprint $table) {
        $table->uuid('id')->primary();
        $table->string('plan_tier');
        $table->string('owner_email')->unique();
        $table->timestamp('trial_ends_at')->nullable();
        $table->timestamps();
    });
}

// database/migrations/tenant/2024_01_01_create_players_table.php (TENANT)
public function up()
{
    Schema::create('players', function