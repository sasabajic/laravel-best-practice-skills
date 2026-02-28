````skill
---
name: laravel-eloquent-database
description: Laravel Eloquent ORM best practices, database migrations, relationships, model conventions, query optimization, N+1 prevention, seeders, factories, scopes, accessors, mutators, and casts. Activates when working with models, database, queries, or migrations.
---

# Laravel Eloquent & Database Best Practices

Follow these practices when working with Eloquent models, database migrations, queries, and data layer.

## Model Conventions

### Model Structure Order

Organize model internals in this consistent order:

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

final class Order extends Model
{
    use HasFactory;
    use SoftDeletes;

    // 1. Constants
    public const STATUS_PENDING = 'pending'; // Prefer Enums over constants

    // 2. Properties ($table, $fillable, $casts, $hidden, $with, etc.)
    protected $fillable = [
        'user_id',
        'status',
        'total',
        'notes',
    ];

    protected $hidden = [
        'internal_notes',
    ];

    protected $with = [
        'items', // Default eager load
    ];

    // 3. Casts method (Laravel 11+)
    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'total' => 'decimal:2',
            'metadata' => 'array',
            'shipped_at' => 'datetime',
            'is_priority' => 'boolean',
        ];
    }

    // 4. Boot / booted methods
    protected static function booted(): void
    {
        static::creating(function (Order $order) {
            $order->number ??= OrderNumberGenerator::next();
        });
    }

    // 5. Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    // 6. Scopes
    public function scopeActive(Builder $builder): Builder
    {
        return $builder->where('status', OrderStatus::Active);
    }

    public function scopeForUser(Builder $builder, User $user): Builder
    {
        return $builder->where('user_id', $user->id);
    }

    // 7. Accessors & Mutators (Attribute cast syntax)
    protected function formattedTotal(): Attribute
    {
        return Attribute::make(
            get: fn () => number_format((float) $this->total, 2, '.', ','),
        );
    }

    // 8. Custom methods
    public function isPending(): bool
    {
        return $this->status === OrderStatus::Pending;
    }

    public function canBeCancelled(): bool
    {
        return in_array($this->status, [OrderStatus::Pending, OrderStatus::Processing]);
    }

    public function markAsShipped(): void
    {
        $this->update([
            'status' => OrderStatus::Shipped,
            'shipped_at' => now(),
        ]);
    }
}
```

### Model Rules

- **Always use `$fillable`** — never use `$guarded = []` (mass assignment protection)
- **Always type relationship return types**: `BelongsTo`, `HasMany`, `HasOne`, etc.
- **Use Enums for status fields** instead of string constants
- **Use `$casts` method** (Laravel 11+) instead of `$casts` property
- **Use `readonly` properties** when combined with DTOs
- **Prefer `$with`** for relationships that are almost always needed
- **Use model observers** for complex lifecycle hooks instead of `booted()`
- Mark models as `final` unless inheritance is needed

### Use Enums for Statuses

```php
<?php

declare(strict_types=1);

namespace App\Enums;

enum OrderStatus: string
{
    case Pending = 'pending';
    case Processing = 'processing';
    case Shipped = 'shipped';
    case Delivered = 'delivered';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Processing => 'Processing',
            self::Shipped => 'Shipped',
            self::Delivered => 'Delivered',
            self::Cancelled => 'Cancelled',
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::Pending => 'yellow',
            self::Processing => 'blue',
            self::Shipped => 'indigo',
            self::Delivered => 'green',
            self::Cancelled => 'red',
        };
    }
}
```

## Relationships

### Always Define Both Sides

```php
// User model
public function orders(): HasMany
{
    return $this->hasMany(Order::class);
}

// Order model
public function user(): BelongsTo
{
    return $this->belongsTo(User::class);
}
```

### Use Relationship Query Methods

```php
// GOOD — query through relationships
$user->orders()->where('status', OrderStatus::Active)->get();

// GOOD — existence check
User::whereHas('orders', fn ($q) => $q->where('total', '>', 100))->get();

// GOOD — count without loading
$user->loadCount('orders');

// GOOD — aggregate without loading
$user->orders()->sum('total');
```

## Query Optimization

### Prevent N+1 — ALWAYS Eager Load

```php
// BAD — N+1 problem
$orders = Order::all();
foreach ($orders as $order) {
    echo $order->user->name; // Separate query per order!
}

// GOOD — eager load
$orders = Order::with('user')->get();
foreach ($orders as $order) {
    echo $order->user->name; // No additional queries
}

// GOOD — nested eager loading
Order::with(['user', 'items.product'])->get();

// GOOD — constrained eager loading
Order::with(['items' => fn ($q) => $q->where('quantity', '>', 1)])->get();
```

### Enable Lazy Loading Prevention

In `AppServiceProvider::boot()`:

```php
Model::preventLazyLoading(! $this->app->isProduction());
```

### Select Only What You Need

```php
// GOOD — select specific columns
User::select(['id', 'name', 'email'])->get();

// GOOD — when using relationships, include the foreign key
Order::select(['id', 'user_id', 'total'])->with('user:id,name')->get();
```

### Use Chunking for Large Datasets

```php
// GOOD — process in chunks to avoid memory issues
User::chunk(1000, function ($users) {
    foreach ($users as $user) {
        // process
    }
});

// GOOD — lazy collection for memory efficiency
User::lazy()->each(function ($user) {
    // process one at a time, memory efficient
});

// GOOD — cursor for maximum memory efficiency (one model at a time)
foreach (User::cursor() as $user) {
    // process
}
```

### Use Database-Level Operations

```php
// GOOD — update at database level, not in PHP
Order::where('status', 'pending')
    ->where('created_at', '<', now()->subDays(30))
    ->update(['status' => 'cancelled']);

// GOOD — increment/decrement without loading model
$product->increment('views');
$account->decrement('balance', $amount);

// GOOD — insert many at once
User::insert($arrayOfUsers); // No events fired
User::upsert($users, ['email'], ['name']); // Insert or update
```

## Scopes

### Use Scopes for Reusable Query Logic

```php
// In model
public function scopeActive(Builder $builder): Builder
{
    return $builder->where('is_active', true);
}

public function scopeCreatedBetween(Builder $builder, Carbon $from, Carbon $to): Builder
{
    return $builder->whereBetween('created_at', [$from, $to]);
}

// Usage — chainable
User::active()->createdBetween($from, $to)->get();
```

### Global Scopes for Always-Applied Filters

```php
// Use sparingly — only when a filter should ALWAYS apply
protected static function booted(): void
{
    static::addGlobalScope('active', function (Builder $builder) {
        $builder->where('is_active', true);
    });
}
```

## Migrations

### Migration Best Practices

```php
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('number')->unique();
            $table->string('status')->default('pending')->index();
            $table->decimal('subtotal', 10, 2);
            $table->decimal('tax', 10, 2)->default(0);
            $table->decimal('total', 10, 2);
            $table->text('notes')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('shipped_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            // Composite indexes for common queries
            $table->index(['user_id', 'status']);
            $table->index(['created_at', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
```

### Migration Rules

- **Always write `down()` method** for rollback capability
- **Use `foreignId()` with `constrained()`** for foreign keys
- Define **cascade behavior** explicitly: `cascadeOnDelete()`, `nullOnDelete()`
- **Add indexes** for columns used in WHERE, ORDER BY, JOIN
- **Use `after()` method** to control column position in modification migrations
- **Never modify existing migrations** in production — create new ones
- **Use descriptive names**: `add_phone_to_users_table`, `create_order_items_table`

## Seeders & Factories

### Factory Convention

```php
final class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => Hash::make('password'),
        ];
    }

    // Named states for variations
    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => UserRole::Admin,
        ]);
    }

    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }

    // Relationships in factory
    public function withOrders(int $count = 3): static
    {
        return $this->has(Order::factory()->count($count));
    }
}
```

### Seeder Convention

```php
final class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Static/reference data first
        $this->call([
            RoleSeeder::class,
            PermissionSeeder::class,
            CategorySeeder::class,
        ]);

        // Then test data (only in non-production)
        if (! app()->isProduction()) {
            $this->call([
                UserSeeder::class,
                OrderSeeder::class,
            ]);
        }
    }
}
```

## Query Builder Tips

```php
// Use when() for conditional queries
User::query()
    ->when($request->search, fn ($q, $search) => $q->where('name', 'like', "%{$search}%"))
    ->when($request->role, fn ($q, $role) => $q->where('role', $role))
    ->when($request->sort, fn ($q, $sort) => $q->orderBy($sort), fn ($q) => $q->latest())
    ->paginate($request->per_page ?? 15);

// Use whereRelation for simple relationship conditions
Order::whereRelation('user', 'is_vip', true)->get();

// Use withAggregate for computed values
User::withSum('orders', 'total')
    ->withCount('orders')
    ->having('orders_sum_total', '>', 1000)
    ->get();
```

````
