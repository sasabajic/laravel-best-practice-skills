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

## UUID / ULID Primary Keys

Use UUID or ULID primary keys when you need non-sequential, globally unique identifiers — for example, when IDs are exposed in URLs or APIs, when merging data across distributed systems, or when you want to prevent enumeration attacks.

### Migration Examples

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table): void {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->string('status');
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index('user_id');
        });
    }
};
```

For UUID instead of ULID:

```php
$table->uuid('id')->primary();
$table->uuid('user_id');
```

### Model Trait Usage

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

final class Order extends Model
{
    use HasFactory;
    use HasUlids;

    protected $fillable = [
        'user_id',
        'status',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

For UUID, use `HasUuids` instead of `HasUlids`:

```php
use Illuminate\Database\Eloquent\Concerns\HasUuids;

final class Order extends Model
{
    use HasUuids;
}
```

### When to Use UUID/ULID vs Auto-Increment

| Scenario | Recommended |
|---|---|
| IDs exposed in URLs or APIs | UUID / ULID |
| Distributed systems or multi-database merging | UUID / ULID |
| Preventing ID enumeration attacks | UUID / ULID |
| Internal-only IDs, high write throughput | Auto-increment |
| Join-heavy queries on large tables | Auto-increment |

Prefer **ULID** over UUID when you need time-sortable identifiers — ULIDs are lexicographically ordered by creation time, which results in better index locality and insert performance compared to random UUIDs.

### Performance Considerations

- UUID/ULID columns are 16 bytes (binary) or 26–36 characters (string) vs 4–8 bytes for integers.
- Larger primary keys increase index size and memory usage for every index referencing that key.
- ULIDs are time-ordered, so B-tree inserts remain sequential — similar to auto-increment performance.
- Random UUIDs (v4) cause index fragmentation on high-write tables; prefer ULIDv7 or ordered UUIDs.
- Always store as the native column type (`ulid()` / `uuid()`), not as `string()`.

### Rules

- Use `HasUlids` or `HasUuids` trait — never generate IDs manually in application code.
- Match the foreign key column type exactly to the parent's primary key type.
- Add explicit indexes on foreign key columns (`$table->index('user_id')`).
- Do not mix auto-increment and UUID/ULID primary keys within the same bounded context.
- Prefer ULID over UUID for new projects unless you have a specific need for UUID format.
- See **laravel-architecture** skill for guidance on structuring models across bounded contexts.
- See **laravel-performance** skill for indexing and query optimization with non-integer keys.

## Polymorphic Relationships

Use polymorphic relationships when multiple models share a common relation — for example, comments that belong to both posts and videos, or tags applied to many different models.

### morphTo / morphMany / morphOne Examples

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

final class Comment extends Model
{
    use HasFactory;

    protected $fillable = [
        'body',
        'user_id',
    ];

    public function commentable(): MorphTo
    {
        return $this->morphTo();
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\Relations\MorphOne;

final class Post extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'body',
    ];

    public function comments(): MorphMany
    {
        return $this->morphMany(Comment::class, 'commentable');
    }

    public function latestComment(): MorphOne
    {
        return $this->morphOne(Comment::class, 'commentable')->latestOfMany();
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphMany;

final class Video extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'url',
    ];

    public function comments(): MorphMany
    {
        return $this->morphMany(Comment::class, 'commentable');
    }
}
```

### morphToMany (Many-to-Many Polymorphic)

Tags applied to multiple model types:

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphToMany;

final class Tag extends Model
{
    use HasFactory;

    protected $fillable = ['name'];

    public function posts(): MorphToMany
    {
        return $this->morphedByMany(Post::class, 'taggable');
    }

    public function videos(): MorphToMany
    {
        return $this->morphedByMany(Video::class, 'taggable');
    }
}
```

```php
// In Post model
public function tags(): MorphToMany
{
    return $this->morphToMany(Tag::class, 'taggable');
}

// In Video model
public function tags(): MorphToMany
{
    return $this->morphToMany(Tag::class, 'taggable');
}
```

Migration for the polymorphic pivot table:

```php
Schema::create('taggables', function (Blueprint $table): void {
    $table->id();
    $table->foreignId('tag_id')->constrained()->cascadeOnDelete();
    $table->morphs('taggable');
    $table->timestamps();

    $table->unique(['tag_id', 'taggable_id', 'taggable_type']);
});
```

### Custom Morph Map

Always define a morph map in `AppServiceProvider` to decouple class names from the database:

```php
<?php

declare(strict_types=1);

namespace App\Providers;

use App\Models\Post;
use App\Models\Video;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Relation::enforceMorphMap([
            'post' => Post::class,
            'video' => Video::class,
        ]);
    }
}
```

### Rules

- Always define a custom morph map — never store fully qualified class names in the database.
- Use `enforceMorphMap()` to throw an exception if an unmapped morph type is encountered.
- Add a composite index on `[commentable_type, commentable_id]` using `$table->morphs()` (it does this automatically).
- Eager load polymorphic relations to avoid N+1 queries: `Comment::with('commentable')->get()`.
- Prefer polymorphic relationships over separate `post_comments` / `video_comments` tables when the schema is identical.
- See **laravel-architecture** skill for when to extract shared behavior into interfaces vs polymorphic relations.

## Database Transactions

Use transactions to ensure a group of database operations either all succeed or all fail — maintaining data integrity.

### DB::transaction() with Closure

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Support\Facades\DB;

final class OrderService
{
    public function createOrder(array $data): Order
    {
        return DB::transaction(function () use ($data): Order {
            $order = Order::create([
                'user_id' => $data['user_id'],
                'status' => 'pending',
                'total' => 0,
            ]);

            $total = 0;

            foreach ($data['items'] as $item) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'price' => $item['price'],
                ]);

                $total += $item['quantity'] * $item['price'];
            }

            $order->update(['total' => $total]);

            return $order;
        });
    }
}
```

### Manual Transactions

Use manual transactions when you need fine-grained control over commit and rollback logic:

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Account;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class TransferService
{
    public function transfer(Account $from, Account $to, int $amount): void
    {
        DB::beginTransaction();

        try {
            $from->decrement('balance', $amount);
            $to->increment('balance', $amount);

            if ($from->fresh()->balance < 0) {
                throw new RuntimeException('Insufficient funds.');
            }

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();

            throw $e;
        }
    }
}
```

### Nested Transactions (Savepoints)

Laravel automatically uses savepoints for nested `DB::transaction()` calls:

```php
DB::transaction(function (): void {
    $user = User::create([...]);

    // This creates a savepoint — if it fails, only this block rolls back
    try {
        DB::transaction(function () use ($user): void {
            $user->profile()->create([...]);
            $user->settings()->create([...]);
        });
    } catch (\Throwable $e) {
        report($e);
        // Outer transaction continues — user is still created
    }
});
```

### Deadlock Handling and Retry

Pass a retry count as the second argument to `DB::transaction()`:

```php
// Retry up to 3 times on deadlock
DB::transaction(function (): void {
    $product = Product::lockForUpdate()->find($productId);
    $product->decrement('stock', $quantity);
}, attempts: 3);
```

### When to Use Transactions

| Scenario | Use Transaction? |
|---|---|
| Creating a parent record with children | Yes |
| Transferring balances between accounts | Yes |
| Single insert or update | Usually no |
| Read-only queries | No |
| Operations spanning multiple services/APIs | Use saga pattern instead |

### Rules

- Prefer `DB::transaction()` with a closure over manual `beginTransaction()` / `commit()` — it handles rollback automatically.
- Keep transactions short — avoid HTTP calls, queue dispatches, or file I/O inside a transaction.
- Use `lockForUpdate()` when reading data that will be modified within the same transaction.
- Set a retry `attempts` count for operations prone to deadlocks.
- Dispatch events and jobs **after** the transaction commits using `afterCommit()` on queued jobs or `DB::afterCommit()`.
- See **laravel-architecture** skill for structuring service classes that use transactions.
- See **laravel-performance** skill for impact of long-running transactions on connection pools.

## Full-Text Search with Laravel Scout

Use Laravel Scout when you need fast, relevance-ranked full-text search beyond what SQL `LIKE` or `FULLTEXT` indexes provide.

### Installation and Configuration

```bash
composer require laravel/scout
php artisan vendor:publish --provider="Laravel\Scout\ScoutServiceProvider"
```

Set the driver in `.env`:

```dotenv
SCOUT_DRIVER=meilisearch
# or: algolia, database, collection
```

### Making Models Searchable

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Laravel\Scout\Searchable;

final class Article extends Model
{
    use HasFactory;
    use Searchable;

    protected $fillable = [
        'title',
        'body',
        'author_id',
        'published_at',
    ];

    /**
     * @return array<string, mixed>
     */
    public function toSearchableArray(): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'body' => $this->body,
            'author_name' => $this->author?->name,
            'published_at' => $this->published_at?->timestamp,
        ];
    }

    public function searchableAs(): string
    {
        return 'articles_index';
    }
}
```

### Searching with Scout

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Article;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class ArticleSearchController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $articles = Article::search($request->string('q'))
            ->where('published_at', '<=', now()->timestamp)
            ->paginate(15);

        return response()->json($articles);
    }
}
```

Advanced search with query callback for combining Scout with Eloquent:

```php
Article::search('laravel best practices')
    ->query(fn ($query) => $query->with(['author', 'tags']))
    ->get();
```

### Driver Comparison

| Driver | Best For | Notes |
|---|---|---|
| Meilisearch | Most Laravel apps | Open-source, fast, typo-tolerant, self-hostable |
| Algolia | Large scale, managed | Hosted SaaS, powerful relevance tuning |
| Database | Simple search needs | Uses SQL `LIKE` / `FULLTEXT`, no extra infrastructure |
| Collection | Testing | In-memory, no persistence, test environments only |

### When to Use Scout vs LIKE Queries

| Scenario | Recommendation |
|---|---|
| Typo-tolerant, relevance-ranked search | Scout (Meilisearch / Algolia) |
| Simple exact or prefix match on one column | `WHERE column LIKE 'term%'` |
| Full-text search on a few columns, low traffic | Database driver or MySQL `FULLTEXT` index |
| Autocomplete / search-as-you-type | Scout (Meilisearch / Algolia) |
| Filtering by indexed columns without text search | Eloquent query — do not use Scout |

### Rules

- Define `toSearchableArray()` explicitly — do not index the entire model.
- Only include attributes that users actually search on or filter by.
- Use `searchableAs()` to define a stable index name — avoid relying on table name conventions.
- Keep search indexes in sync by dispatching Scout's `MakeSearchable` / `RemoveFromSearch` jobs via model observers or after transactions commit.
- Use the `database` or `collection` driver in tests to avoid external service dependencies.
- See **laravel-performance** skill for caching search results and optimizing index sync.
- See **laravel-architecture** skill for placing search logic in dedicated query/service classes.

## Model Pruning

Use model pruning to automatically clean up stale or expired records — such as old logs, revoked tokens, or soft-deleted models past their retention period.

### Prunable vs MassPrunable

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\MassPrunable;

final class ActivityLog extends Model
{
    use MassPrunable;

    protected $fillable = [
        'description',
        'subject_type',
        'subject_id',
        'causer_id',
    ];

    public function prunable(): Builder
    {
        return static::where('created_at', '<=', now()->subMonths(3));
    }
}
```

Use `Prunable` (not `MassPrunable`) when you need model events to fire during deletion — for example, to clean up related files:

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Prunable;
use Illuminate\Support\Facades\Storage;

final class TemporaryUpload extends Model
{
    use Prunable;

    protected $fillable = [
        'path',
        'expires_at',
    ];

    public function prunable(): Builder
    {
        return static::where('expires_at', '<=', now());
    }

    protected function pruning(): void
    {
        Storage::delete($this->path);
    }
}
```

### Practical Examples

Pruning expired personal access tokens:

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\MassPrunable;
use Laravel\Sanctum\PersonalAccessToken as SanctumToken;

final class PersonalAccessToken extends SanctumToken
{
    use MassPrunable;

    public function prunable(): Builder
    {
        return static::where('expires_at', '<=', now());
    }
}
```

### Schedule Integration

Register the prune command in `routes/console.php` or your console kernel:

```php
use Illuminate\Support\Facades\Schedule;

Schedule::command('model:prune')->daily();

// Prune specific models with a custom chunk size
Schedule::command('model:prune', [
    '--model' => [ActivityLog::class, TemporaryUpload::class],
    '--chunk' => 500,
])->daily();
```

### Rules

- Use `MassPrunable` for bulk deletes where model events are not needed — it uses `DELETE` queries directly and is significantly faster.
- Use `Prunable` only when you need the `pruning()` hook to run per-model cleanup logic (e.g., deleting files).
- Always define a time-based condition in `prunable()` — never prune without a retention boundary.
- Schedule `model:prune` to run daily (or more frequently for high-volume tables).
- Test prunable queries by calling `Model::prunable()->count()` before deploying.
- See **laravel-performance** skill for chunk size tuning and impact on large tables.
- See **laravel-architecture** skill for organizing cleanup logic in dedicated service classes.
