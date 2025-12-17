---
trigger: glob
globs: database/**/*.php
---

# Zone14 - Database Rules (Glob: database/**/*.php)

## 🗄️ Migration Standards

### UUIDv7 Template
```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('players', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('team_id')->constrained()->cascadeOnDelete();
            $table->string('first_name');
            $table->string('last_name');
            $table->date('birth_date');
            $table->enum('position', ['goalkeeper', 'defender', 'midfielder', 'forward']);
            $table->boolean('is_active')->default(true);
            $table->json('metadata')->nullable();
            $table->timestamps();
            
            $table->index('team_id');
            $table->index(['team_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('players');
    }
};
```

---

## 📁 Central vs Tenant Migrations

### Central (database/migrations/)
```php
// Tenants table
Schema::create('tenants', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->string('plan_tier');
    $table->string('owner_email')->unique();
    $table->timestamp('trial_ends_at')->nullable();
    $table->timestamps();
});

// Domains table
Schema::create('domains', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('tenant_id')->constrained()->cascadeOnDelete();
    $table->string('domain')->unique();
    $table->boolean('is_primary')->default(false);
    $table->timestamps();
});
```

### Tenant (database/migrations/tenant/)
```php
// All business tables: players, matches, teams, injuries, workload
Schema::create('matches', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('home_team_id')->constrained('teams');
    $table->foreignUuid('away_team_id')->constrained('teams');
    $table->integer('home_score')->default(0);
    $table->integer('away_score')->default(0);
    $table->enum('status', ['scheduled', 'in_progress', 'finished'])->default('scheduled');
    $table->timestamp('kickoff_at');
    $table->timestamps();
    
    $table->index(['home_team_id', 'status']);
    $table->index('kickoff_at');
});
```

---

## 🔗 Foreign Keys & Relationships

```php
// Standard FK
$table->foreignUuid('team_id')->constrained()->cascadeOnDelete();

// Nullable FK (self-referencing)
$table->foreignUuid('manager_id')->nullable()->constrained('users')->nullOnDelete();

// Polymorphic
$table->uuidMorphs('commentable'); // Creates commentable_type + commentable_id
```

---

## 📊 Index Strategies

### Simple & Composite
```php
$table->index('email');
$table->index(['team_id', 'status']); // Order matters!
$table->unique(['team_id', 'jersey_number']); // Unique per team
```

### Full-Text (PostgreSQL)
```php
$table->fullText(['first_name', 'last_name']);

// Query: Player::whereFullText(['first_name', 'last_name'], 'John')->get();
```

### JSON Index (GIN)
```php
// In migration up()
DB::statement('CREATE INDEX players_metadata_gin ON players USING GIN (metadata)');

// Query: Player::whereJsonContains('metadata->skills', 'goalkeeper')->get();
```

---

## 🔄 Zero-Downtime Migrations

### Add Column (Safe)
```php
Schema::table('players', function (Blueprint $table) {
    $table->string('nickname')->nullable()->after('last_name');
});
```

### Add NOT NULL (With Default)
```php
Schema::table('players', function (Blueprint $table) {
    $table->string('position')->default('midfielder'); // Temporary default
});
```

### Index CONCURRENTLY (PostgreSQL)
```php
public function up(): void
{
    // ✅ Non-blocking
    DB::statement('CREATE INDEX CONCURRENTLY players_name_idx ON players (last_name)');
}

public function down(): void
{
    DB::statement('DROP INDEX CONCURRENTLY IF EXISTS players_name_idx');
}
```

### Remove Column (Two-Step)
```php
// Step 1: Make nullable
Schema::table('players', function (Blueprint $table) {
    $table->string('old_field')->nullable()->change();
});

// Deploy + verify no code uses old_field

// Step 2: Drop
Schema::table('players', function (Blueprint $table) {
    $table->dropColumn('old_field');
});
```

---

## 🌱 Seeders

### Central Seeder
```php
// database/seeders/TenantSeeder.php
public function run(): void
{
    $tenant = Tenant::create([
        'plan_tier' => 'pro',
        'owner_email' => 'admin@club.com',
        'company_name' => 'Demo Club',
    ]);
    
    $tenant->domains()->create(['domain' => 'demo.zone14.test']);
}
```

### Tenant Seeder
```php
// database/seeders/tenant/TeamSeeder.php
public function run(): void
{
    $team = Team::create(['name' => 'First Team']);
    
    Player::factory()->count(25)->for($team)->create();
}
```

---

## 🏭 Factories

```php
// database/factories/PlayerFactory.php
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
            ],
        ];
    }
    
    public function goalkeeper(): static
    {
        return $this->state(['position' => 'goalkeeper', 'jersey_number' => 1]);
    }
}

// Usage: Player::factory()->goalkeeper()->create();
```

---

## 📈 Performance Tables

### Workload (ACWR)
```php
Schema::create('workloads', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('player_id')->constrained()->cascadeOnDelete();
    $table->date('date');
    $table->integer('duration'); // Minutes
    $table->integer('rpe'); // 1-10
    $table->integer('load')->storedAs('duration * rpe'); // Computed
    $table->timestamps();
    
    $table->unique(['player_id', 'date']);
    $table->index(['player_id', 'date']); // Range queries
});
```

### Match Stats
```php
Schema::create('match_player_stats', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('match_id')->constrained()->cascadeOnDelete();
    $table->foreignUuid('player_id')->constrained()->cascadeOnDelete();
    $table->integer('goals')->default(0);
    $table->integer('assists')->default(0);
    $table->integer('minutes_played')->default(0);
    $table->timestamps();
    
    $table->unique(['match_id', 'player_id']);
});
```

---

## 🔐 Security Tables

### Audit Log (Central)
```php
Schema::create('audit_logs', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->uuid('tenant_id')->nullable()->index();
    $table->foreignUuid('user_id')->nullable()->constrained()->nullOnDelete();
    $table->string('action'); // created, updated, deleted
    $table->string('auditable_type');
    $table->uuid('auditable_id');
    $table->json('old_values')->nullable();
    $table->json('new_values')->nullable();
    $table->timestamps();
    
    $table->index(['auditable_type', 'auditable_id']);
});
```

---

## 🎯 Sport-Specific Tables

### Injuries
```php
Schema::create('injuries', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignUuid('player_id')->constrained()->cascadeOnDelete();
    $table->string('type'); // muscle, ligament, bone
    $table->string('body_part');
    $table->date('injury_date');
    $table->date('expected_return_date')->nullable();
    $table->enum('severity', ['minor', 'moderate', 'severe']);
    $table->timestamps();
    
    $table->index(['player_id', 'injury_date']);
});
```

---

## 🚀 Best Practices

### DO
- ✅ Use UUIDv7 for all PKs
- ✅ CONCURRENTLY for indexes
- ✅ Composite indexes for common queries
- ✅ Never modify merged migrations
- ✅ Test rollback (down())

### DON'T
- ❌ Auto-increment IDs
- ❌ Modify production migrations
- ❌ Block writes with index creation
- ❌ Skip down() method

---

## 📝 Schema Dump (Squashing)

```bash
# Generate schema.dump
php artisan schema:dump

# With prune (delete old migrations)
php artisan schema:dump --prune

# Fresh install uses dump automatically
php artisan migrate:fresh
```

---

**Caratteri: ~5,900** | **Target**: PostgreSQL 18 | UUIDv7 | Zero-downtime | Multi-tenant