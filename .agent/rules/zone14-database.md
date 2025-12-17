---
trigger: glob
globs: database/**/*.php
---

# Zone14 - Database Rules (Glob: database/**/*.php)

Questa regola si applica automaticamente a migrazioni, seeders, e factories nel progetto.

---

## 🗄️ Migration Standards

### UUIDv7 Primary Keys (Obbligatorio)
```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('players', function (Blueprint $table) {
            $table->uuid('id')->primary(); // UUIDv7 via model HasUuids
            $table->foreignUuid('team_id')->constrained()->cascadeOnDelete();
            $table->string('first_name');
            $table->string('last_name');
            $table->date('birth_date');
            $table->enum('position', ['goalkeeper', 'defender', 'midfielder', 'forward']);
            $table->integer('jersey_number')->nullable();
            $table->boolean('is_active')->default(true);
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->softDeletes();
            
            // Indexes
            $table->index('team_id');
            $table->index(['team_id', 'is_active']);
            $table->index('last_name'); // Per search
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('players');
    }
};
```

### Central vs Tenant Migrations

**Central Migrations** (`database/migrations/`):
- Tabelle `tenants`, `domains`
- Tabelle di configurazione globale
- Log audit centralizzati
- Impersonation tokens

```php
// database/migrations/2024_01_01_000000_create_tenants_table.php
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenants', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('plan_tier'); // 'free', 'pro', 'enterprise'
            $table->string('owner_email')->unique();
            $table->string('company_name');
            $table->timestamp('trial_ends_at')->nullable();
            $table->timestamp('archived_at')->nullable();
            $table->json('settings')->nullable();
            $table->timestamps();
            
            $table->index('plan_tier');
            $table->index('archived_at');
        });
    }
};
```

**Tenant Migrations** (`database/migrations/tenant/`):
- Tutto il resto (players, matches, teams, injuries, workload, etc.)
- Eseguiti per ogni schema tenant

```php
// database/migrations/tenant/2024_01_02_000000_create_teams_table.php
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('teams', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('logo_url')->nullable();
            $table->integer('founded_year')->nullable();
            $table->string('stadium')->nullable();
            $table->string('colors')->nullable();
            $table->timestamps();
        });
    }
};
```

---

## 🔗 Foreign Keys & Constraints

### Standard Relationships
```php
Schema::create('matches', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('home_team_id')->constrained('teams')->cascadeOnDelete();
    $table->foreignUuid('away_team_id')->constrained('teams')->cascadeOnDelete();
    $table->integer('home_score')->default(0);
    $table->integer('away_score')->default(0);
    $table->enum('status', ['scheduled', 'in_progress', 'finished', 'cancelled'])->default('scheduled');
    $table->timestamp('kickoff_at');
    $table->timestamp('ended_at')->nullable();
    $table->timestamps();
    
    // Composite indexes per query comuni
    $table->index(['home_team_id', 'status']);
    $table->index(['away_team_id', 'status']);
    $table->index('kickoff_at');
});
```

### Self-Referencing (Optional Nullable)
```php
Schema::create('users', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('manager_id')->nullable()->constrained('users')->nullOnDelete();
    $table->string('email')->unique();
    $table->string('password');
    $table->timestamps();
});
```

### Polymorphic Relations
```php
Schema::create('comments', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->uuidMorphs('commentable'); // Crea commentable_type e commentable_id
    $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
    $table->text('content');
    $table->timestamps();
    
    $table->index(['commentable_type', 'commentable_id']);
});
```

---

## 📊 Index Strategies

### Simple Indexes
```php
$table->index('email'); // Velocizza WHERE email = ?
$table->index('created_at'); // Velocizza ORDER BY created_at
```

### Composite Indexes (Order Matters!)
```php
// Query: WHERE team_id = ? AND status = ?
$table->index(['team_id', 'status']);

// Query: WHERE team_id = ? ORDER BY created_at DESC
$table->index(['team_id', 'created_at']);

// ⚠️ Ordine sbagliato rallenta la query
// Se query è WHERE status = ? AND team_id = ?, l'indice sopra è inefficiente
```

### Unique Constraints
```php
$table->unique('email');
$table->unique(['team_id', 'jersey_number']); // Numero maglia unico per team
```

### Full-Text Search (PostgreSQL)
```php
Schema::create('players', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->string('first_name');
    $table->string('last_name');
    $table->text('biography')->nullable();
    $table->timestamps();
    
    // Full-text index
    $table->fullText(['first_name', 'last_name', 'biography']);
});

// Query usage:
// Player::whereFullText(['first_name', 'last_name'], 'John')->get();
```

### JSON Indexes (PostgreSQL GIN)
```php
public function up(): void
{
    Schema::create('players', function (Blueprint $table) {
        $table->uuid('id')->primary();
        $table->json('metadata')->nullable();
        $table->timestamps();
    });
    
    // Indice GIN per query su JSON
    DB::statement('CREATE INDEX players_metadata_gin ON players USING GIN (metadata)');
}

// Query usage:
// Player::whereJsonContains('metadata->skills', 'goalkeeper')->get();
```

---

## 🔄 Zero-Downtime Migrations

### Add Column (Safe)
```php
public function up(): void
{
    Schema::table('players', function (Blueprint $table) {
        $table->string('nickname')->nullable()->after('last_name');
    });
}
```

### Add NOT NULL Column (Requires Default)
```php
public function up(): void
{
    Schema::table('players', function (Blueprint $table) {
        // ❌ BAD: Crash se ci sono record esistenti
        // $table->string('position');
        
        // ✅ GOOD: Default temporaneo
        $table->string('position')->default('midfielder');
    });
}

// Successiva migrazione per rimuovere default se necessario
public function up(): void
{
    Schema::table('players', function (Blueprint $table) {
        $table->string('position')->default(null)->change();
    });
}
```

### Add Index CONCURRENTLY (PostgreSQL)
```php
public function up(): void
{
    // ❌ BAD: Blocca tabella durante creazione indice
    // Schema::table('players', function (Blueprint $table) {
    //     $table->index('last_name');
    // });
    
    // ✅ GOOD: Non blocca scritture
    DB::statement('CREATE INDEX CONCURRENTLY players_last_name_index ON players (last_name)');
}

public function down(): void
{
    DB::statement('DROP INDEX CONCURRENTLY IF EXISTS players_last_name_index');
}
```

### Remove Column (Two-Step)
```php
// Step 1: Migrazione che rende la colonna nullable
public function up(): void
{
    Schema::table('players', function (Blueprint $table) {
        $table->string('old_field')->nullable()->change();
    });
}

// Deploy e verifica che nessun codice usi più old_field

// Step 2: Migrazione che rimuove la colonna
public function up(): void
{
    Schema::table('players', function (Blueprint $table) {
        $table->dropColumn('old_field');
    });
}
```

---

## 🌱 Seeders

### Central Seeder (Tenants)
```php
// database/seeders/TenantSeeder.php
namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Tenant;

class TenantSeeder extends Seeder
{
    public function run(): void
    {
        $demoTenant = Tenant::create([
            'plan_tier' => 'pro',
            'owner_email' => 'demo@juventus.com',
            'company_name' => 'Juventus FC',
        ]);
        
        $demoTenant->domains()->create([
            'domain' => 'juventus.zone14.test',
        ]);
    }
}
```

### Tenant Seeder (Teams, Players)
```php
// database/seeders/tenant/TeamSeeder.php
namespace Database\Seeders\Tenant;

use Illuminate\Database\Seeder;
use App\Models\Team;
use App\Models\Player;

class TeamSeeder extends Seeder
{
    public function run(): void
    {
        $team = Team::create([
            'name' => 'First Team',
            'founded_year' => 2020,
            'stadium' => 'Home Stadium',
        ]);
        
        // Crea giocatori
        Player::factory()
            ->count(25)
            ->for($team)
            ->create();
    }
}
```

---

## 🏭 Factories

### Player Factory
```php
// database/factories/PlayerFactory.php
namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use App\Models\Team;

class PlayerFactory extends Factory
{
    public function definition(): array
    {
        return [
            'first_name' => fake()->firstName(),
            'last_name' => fake()->lastName(),
            'birth_date' => fake()->date('Y-m-d', '-18 years'),
            'position' => fake()->randomElement(['goalkeeper', 'defender', 'midfielder', 'forward']),
            'jersey_number' => fake()->unique()->numberBetween(1, 99),
            'is_active' => true,
            'metadata' => [
                'height' => fake()->numberBetween(165, 200),
                'weight' => fake()->numberBetween(60, 95),
                'preferred_foot' => fake()->randomElement(['left', 'right', 'both']),
                'skills' => fake()->randomElements(
                    ['speed', 'dribbling', 'passing', 'shooting', 'heading', 'tackling'],
                    fake()->numberBetween(2, 4)
                ),
            ],
        ];
    }
    
    // State methods
    public function goalkeeper(): static
    {
        return $this->state(fn (array $attributes) => [
            'position' => 'goalkeeper',
            'jersey_number' => fake()->randomElement([1, 12, 13, 25]),
        ]);
    }
    
    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => false,
        ]);
    }
}

// Usage:
// Player::factory()->goalkeeper()->create();
// Player::factory()->count(5)->for($team)->create();
```

### Match Factory (Relationships)
```php
// database/factories/MatchFactory.php
namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use App\Models\Team;

class MatchFactory extends Factory
{
    public function definition(): array
    {
        return [
            'home_team_id' => Team::factory(),
            'away_team_id' => Team::factory(),
            'home_score' => 0,
            'away_score' => 0,
            'status' => 'scheduled',
            'kickoff_at' => fake()->dateTimeBetween('now', '+1 month'),
        ];
    }
    
    public function finished(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'finished',
            'home_score' => fake()->numberBetween(0, 5),
            'away_score' => fake()->numberBetween(0, 5),
            'ended_at' => fake()->dateTimeBetween('-1 month', 'now'),
        ]);
    }
    
    public function inProgress(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'in_progress',
            'kickoff_at' => now()->subMinutes(45),
        ]);
    }
}
```

---

## 📈 Performance Tables (ACWR, Stats)

### Workload Tracking
```p