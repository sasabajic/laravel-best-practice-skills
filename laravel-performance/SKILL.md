---
name: laravel-performance
description: Laravel application performance optimization including caching strategies, queue and job management, database query optimization, eager loading, Redis usage, lazy collections, indexing, and profiling. Activates when working with caching, queues, jobs, optimization, or performance-related tasks.
---

# Laravel Performance Best Practices

Follow these performance practices to build fast, scalable Laravel applications.

## Caching Strategy

### Cache Frequently Accessed Data

```php
// GOOD — cache expensive queries
$categories = Cache::remember('categories:active', now()->addHours(6), function () {
    return Category::with('subcategories')
        ->where('is_active', true)
        ->orderBy('sort_order')
        ->get();
});

// GOOD — cache with tags (requires Redis/Memcached)
$user = Cache::tags(['users'])->remember("user:{$id}", now()->addHour(), function () use ($id) {
    return User::with(['roles', 'permissions'])->findOrFail($id);
});

// Invalidate tagged cache
Cache::tags(['users'])->flush();

// GOOD — cache individual computed values
$stats = Cache::remember('dashboard:stats', now()->addMinutes(15), function () {
    return [
        'total_users' => User::count(),
        'total_orders' => Order::count(),
        'revenue' => Order::where('status', 'completed')->sum('total'),
    ];
});
```

### Cache Invalidation

```php
// In Observer or Event Listener — invalidate when data changes
final class OrderObserver
{
    public function created(Order $order): void
    {
        Cache::forget("user:{$order->user_id}:orders");
        Cache::tags(['dashboard'])->flush();
    }

    public function updated(Order $order): void
    {
        Cache::forget("order:{$order->id}");
        Cache::forget("user:{$order->user_id}:orders");
    }
}
```

### Caching Rules

- **Cache read-heavy, write-light data** (settings, categories, permissions)
- Use `remember()` with appropriate TTL — not forever unless truly static
- Use **cache tags** for grouped invalidation (requires Redis)
- Invalidate cache when data changes — use Observers or Events
- Use **Redis** as cache driver in production (not file or database)
- Cache at the right layer: DB query results, computed values, API responses
- Don't cache user-specific data unless using per-user keys

## Queues and Jobs

### Job Convention

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Mail\InvoiceEmail;
use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\Middleware\WithoutOverlapping;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

final class SendInvoiceEmail implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;
    public int $backoff = 60; // seconds between retries
    public int $timeout = 120; // max execution time
    public int $maxExceptions = 2;

    public function __construct(
        public readonly Order $order,
    ) {}

    // Prevent overlapping jobs for same order
    public function middleware(): array
    {
        return [
            new WithoutOverlapping($this->order->id),
        ];
    }

    public function handle(): void
    {
        Mail::to($this->order->user->email)
            ->send(new InvoiceEmail($this->order));
    }

    // Handle permanent failure
    public function failed(\Throwable $exception): void
    {
        // Log, notify admin, etc.
        Log::error("Failed to send invoice for order {$this->order->id}", [
            'exception' => $exception->getMessage(),
        ]);
    }

    // Determine if job should be retried
    public function retryUntil(): \DateTime
    {
        return now()->addHours(24);
    }
}
```

### Dispatching Jobs

```php
// Basic dispatch
SendInvoiceEmail::dispatch($order);

// Dispatch to specific queue
SendInvoiceEmail::dispatch($order)->onQueue('emails');

// Delayed dispatch
SendInvoiceEmail::dispatch($order)->delay(now()->addMinutes(10));

// Job chaining — run in sequence
Bus::chain([
    new ProcessPayment($order),
    new UpdateInventory($order),
    new SendInvoiceEmail($order),
])->dispatch();

// Job batching — run in parallel with tracking
Bus::batch([
    new SendInvoiceEmail($order1),
    new SendInvoiceEmail($order2),
    new SendInvoiceEmail($order3),
])->then(function (Batch $batch) {
    // All jobs completed
})->catch(function (Batch $batch, \Throwable $e) {
    // First failure
})->finally(function (Batch $batch) {
    // Batch finished (success or failure)
})->dispatch();
```

### Queue Rules

- **Queue everything that's slow**: emails, PDFs, API calls, image processing, reports
- Set appropriate `$tries`, `$backoff`, `$timeout` on every job
- Handle failures in `failed()` method
- Use `WithoutOverlapping` middleware to prevent duplicate processing
- Use job **batching** for bulk operations with progress tracking
- Use job **chaining** for sequential dependent operations
- Use **different queues** for priority: `high`, `default`, `low`
- Use **Redis or SQS** as queue driver in production (not database or sync)

## Database Performance

### Indexing Strategy

```php
// Add indexes for columns used in WHERE, ORDER BY, JOIN, and GROUP BY
Schema::table('orders', function (Blueprint $table) {
    // Single column indexes
    $table->index('status');
    $table->index('created_at');

    // Composite indexes (order matters — most selective first)
    $table->index(['user_id', 'status']);
    $table->index(['status', 'created_at']); // For status + date range queries

    // Unique indexes where appropriate
    $table->unique('number');
});
```

### Query Optimization

```php
// GOOD — select only needed columns
User::select(['id', 'name', 'email'])->get();

// GOOD — use chunk for large datasets
Order::where('status', 'pending')
    ->chunk(500, function ($orders) {
        foreach ($orders as $order) {
            ProcessOrder::dispatch($order);
        }
    });

// GOOD — use cursor for memory-efficient iteration
foreach (User::cursor() as $user) {
    // processes one model at a time
}

// GOOD — bulk operations at database level
Order::where('created_at', '<', now()->subYear())->delete();

// GOOD — avoid loading models for counts
$count = Order::where('status', 'active')->count();

// GOOD — use subqueries instead of PHP loops
User::addSelect([
    'latest_order_date' => Order::select('created_at')
        ->whereColumn('user_id', 'users.id')
        ->latest()
        ->limit(1),
])->get();
```

### N+1 Prevention Checklist

1. Enable `Model::preventLazyLoading()` in non-production
2. Always use `with()` for relationships you'll access
3. Use `loadMissing()` for conditional eager loading
4. Use `withCount()` instead of `$model->relation->count()`
5. Use `withAggregate()` for sums, averages, etc.
6. Install **Laravel Debugbar** or **Telescope** in development

## Config & Route Caching

```bash
# Production optimization commands — run during deployment
php artisan config:cache    # Cache all config files into single file
php artisan route:cache     # Cache all routes
php artisan view:cache      # Pre-compile all Blade views
php artisan event:cache     # Cache event/listener mappings
php artisan icons:cache     # If using blade-icons

# Clear caches during development
php artisan optimize:clear
```

## Lazy Collections

```php
// Process millions of records without running out of memory
LazyCollection::make(function () {
    $handle = fopen('large-file.csv', 'r');
    while ($line = fgetcsv($handle)) {
        yield $line;
    }
})->chunk(1000)->each(function ($chunk) {
    // Process 1000 lines at a time
    DB::table('imports')->insert($chunk->toArray());
});

// Eloquent lazy collection
User::lazy()->each(function (User $user) {
    // One model in memory at a time
    $user->recalculateStats();
});
```

## Redis Usage

```php
// Use Redis for:
// 1. Cache (primary cache driver)
// 2. Sessions (faster than database)
// 3. Queues (reliable queue driver)
// 4. Rate limiting (built-in)
// 5. Real-time features (broadcasting)
// 6. Atomic locks

// Atomic locks — prevent race conditions
$lock = Cache::lock('processing-order-' . $order->id, 10);

if ($lock->get()) {
    try {
        // Process order — guaranteed no concurrent processing
        $this->processOrder($order);
    } finally {
        $lock->release();
    }
}
```

## Response Optimization

```php
// Compress API responses
// In middleware or use spatie/laravel-responsecache

// Use pagination — never return unbounded collections
Order::paginate(15); // not Order::all()

// Use API Resources with minimal data
// Only include fields the client needs

// Cache full page responses for public pages
Route::middleware('cache.headers:public;max_age=3600')->group(function () {
    Route::get('products', [ProductController::class, 'index']);
});
```

## Performance Monitoring

- Use **Laravel Telescope** in development for query monitoring
- Use **Laravel Debugbar** for page load analysis
- Monitor slow queries with `DB::listen()` in development
- Use **Horizon** for Redis queue monitoring
- Set up APM (Application Performance Monitoring) in production

```php
// Log slow queries in development
DB::listen(function ($query) {
    if ($query->time > 100) { // > 100ms
        Log::warning('Slow query', [
            'sql' => $query->sql,
            'time' => $query->time . 'ms',
            'bindings' => $query->bindings,
        ]);
    }
});
```
