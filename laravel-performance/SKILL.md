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

## Laravel Octane

Laravel Octane supercharges performance by serving your application using high-powered servers that keep the application in memory between requests, eliminating the bootstrap overhead on every request.

### Installation and Configuration

```bash
composer require laravel/octane
php artisan octane:install
```

### Swoole vs RoadRunner vs FrankenPHP

| Server | Pros | Cons |
|---|---|---|
| Swoole | Fastest, concurrent tasks, coroutines | PHP extension required |
| RoadRunner | Go-based, easy install, no extension | Slightly slower than Swoole |
| FrankenPHP | Modern, HTTP/3, early access support | Newest, smaller ecosystem |

```php
// config/octane.php
return [
    'server' => env('OCTANE_SERVER', 'swoole'), // 'swoole', 'roadrunner', or 'frankenphp'
    'workers' => env('OCTANE_WORKERS', 'auto'),
    'task_workers' => env('OCTANE_TASK_WORKERS', 'auto'),
    'max_execution_time' => 30,
];
```

### Memory Leak Prevention

```php
<?php

declare(strict_types=1);

namespace App\Services;

// BAD — mutable static state leaks between requests
class BadCartService
{
    private static array $items = []; // persists across requests!

    public function add(string $item): void
    {
        self::$items[] = $item;
    }
}

// GOOD — use request-scoped state
final class CartService
{
    private array $items = [];

    public function add(string $item): void
    {
        $this->items[] = $item;
    }

    public function items(): array
    {
        return $this->items;
    }
}
```

Register request-scoped services properly:

```php
<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\CartService;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Bind as non-shared so each request gets a fresh instance
        $this->app->bind(CartService::class);
    }
}
```

### Resolved Services Persist — Watch Out

```php
<?php

declare(strict_types=1);

namespace App\Listeners;

use Laravel\Octane\Events\RequestReceived;

// Reset state between requests using Octane listeners
final class FlushRequestState
{
    public function handle(RequestReceived $event): void
    {
        // Flush any mutable singleton state here
        $event->app->forgetInstance('mutable.service');
    }
}
```

### Concurrent Tasks with Octane

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Laravel\Octane\Facades\Octane;

final class DashboardController extends Controller
{
    public function index(): JsonResponse
    {
        // Run independent queries concurrently (Swoole only)
        [$users, $orders, $revenue] = Octane::concurrently([
            fn () => User::count(),
            fn () => Order::where('status', 'pending')->count(),
            fn () => Order::where('status', 'completed')->sum('total'),
        ]);

        return response()->json(compact('users', 'orders', 'revenue'));
    }
}
```

### When to Use Octane vs Standard PHP-FPM

| Scenario | Recommendation |
|---|---|
| API-heavy, high-throughput services | ✅ Octane |
| Apps relying on global/static state | ❌ PHP-FPM (or refactor first) |
| Real-time features (WebSockets) | ✅ Octane with Swoole |
| Shared hosting or limited control | ❌ PHP-FPM |
| Simple CRUD apps with low traffic | ❌ PHP-FPM (simpler ops) |

> **Cross-reference:** See `laravel-deployment` skill for Octane production deployment strategies.

### Rules

- Use Octane for high-throughput APIs and real-time applications
- Never store mutable state in static properties or singletons
- Bind services as non-shared (`bind`) instead of shared (`singleton`) unless they are truly stateless
- Use `Octane::concurrently()` for independent I/O operations (Swoole only)
- Reset state between requests using Octane listeners when needed
- Test thoroughly under Octane before deploying — service resolution behavior differs from PHP-FPM

## Image Optimization

Optimize images to reduce bandwidth, improve page load times, and enhance user experience.

### Processing with Intervention Image

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\Drivers\Gd\Driver;
use Intervention\Image\ImageManager;

final class ImageOptimizer
{
    private readonly ImageManager $manager;

    public function __construct()
    {
        $this->manager = new ImageManager(new Driver());
    }

    /**
     * Resize on upload — never serve the original.
     */
    public function processUpload(UploadedFile $file, string $path): string
    {
        $image = $this->manager->read($file->getPathname());

        // Constrain to max dimensions, maintaining aspect ratio
        $image->scaleDown(width: 1200, height: 1200);

        // Convert to WebP for smaller file size
        $encoded = $image->toWebp(quality: 80);

        $filename = pathinfo($file->hashName(), PATHINFO_FILENAME) . '.webp';
        $fullPath = "{$path}/{$filename}";

        Storage::disk('public')->put($fullPath, (string) $encoded);

        return $fullPath;
    }

    /**
     * Generate responsive variants for srcset.
     *
     * @return array<int, string>
     */
    public function generateResponsiveVariants(UploadedFile $file, string $path): array
    {
        $widths = [320, 640, 960, 1200];
        $variants = [];

        foreach ($widths as $width) {
            $image = $this->manager->read($file->getPathname());
            $image->scaleDown(width: $width);
            $encoded = $image->toWebp(quality: 80);

            $filename = pathinfo($file->hashName(), PATHINFO_FILENAME) . "-{$width}w.webp";
            $fullPath = "{$path}/{$filename}";

            Storage::disk('public')->put($fullPath, (string) $encoded);
            $variants[$width] = $fullPath;
        }

        return $variants;
    }
}
```

### AVIF Format Conversion

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Gd\Driver;

final class AvifConverter
{
    public function convert(string $sourcePath, string $destPath): void
    {
        $manager = new ImageManager(new Driver());
        $image = $manager->read($sourcePath);

        // AVIF offers ~50% smaller files than JPEG at similar quality
        $encoded = $image->toAvif(quality: 60);

        file_put_contents($destPath, (string) $encoded);
    }
}
```

### Responsive Images in Blade

```html
<!-- GOOD — responsive images with srcset and lazy loading -->
<picture>
    <source
        type="image/webp"
        srcset="
            {{ asset('storage/' . $image['320']) }} 320w,
            {{ asset('storage/' . $image['640']) }} 640w,
            {{ asset('storage/' . $image['960']) }} 960w,
            {{ asset('storage/' . $image['1200']) }} 1200w
        "
        sizes="(max-width: 640px) 100vw, (max-width: 960px) 50vw, 33vw"
    />
    <img
        src="{{ asset('storage/' . $image['640']) }}"
        alt="{{ $altText }}"
        loading="lazy"
        decoding="async"
        width="640"
        height="480"
    />
</picture>
```

### CDN Delivery

```php
// config/filesystems.php — use a CDN URL for public assets
'disks' => [
    'public' => [
        'driver' => 'local',
        'root' => storage_path('app/public'),
        'url' => env('ASSET_URL', '/storage'), // Set ASSET_URL to CDN domain
        'visibility' => 'public',
    ],
],

// .env
// ASSET_URL=https://cdn.example.com/storage
```

> **Cross-reference:** See `laravel-deployment` skill for CDN setup and asset distribution.

### Rules

- Always resize images on upload — never serve original uploads directly
- Convert to WebP or AVIF for modern browsers (50-80% size reduction)
- Generate responsive image variants for different screen sizes
- Use `loading="lazy"` and `decoding="async"` on all below-the-fold images
- Serve images from a CDN for global performance
- Set explicit `width` and `height` attributes to prevent layout shift

## Database Connection Pooling

Efficient connection management reduces database overhead and improves throughput.

### Persistent Connections

```php
// config/database.php
'connections' => [
    'pgsql' => [
        'driver' => 'pgsql',
        'host' => env('DB_HOST', '127.0.0.1'),
        'port' => env('DB_PORT', '5432'),
        'database' => env('DB_DATABASE', 'forge'),
        'username' => env('DB_USERNAME', 'forge'),
        'password' => env('DB_PASSWORD', ''),
        'options' => [
            PDO::ATTR_PERSISTENT => true, // reuse connections across requests
        ],
    ],
],
```

### Connection Pooling with PgBouncer (PostgreSQL)

```ini
; /etc/pgbouncer/pgbouncer.ini
[databases]
myapp = host=127.0.0.1 port=5432 dbname=myapp

[pgbouncer]
listen_port = 6432
pool_mode = transaction   ; release connection after each transaction
max_client_conn = 1000
default_pool_size = 20
```

```env
# .env — point Laravel at PgBouncer instead of PostgreSQL directly
DB_HOST=127.0.0.1
DB_PORT=6432
```

### Read/Write Splitting

```php
// config/database.php
'mysql' => [
    'read' => [
        'host' => [
            env('DB_READ_HOST_1', '10.0.0.2'),
            env('DB_READ_HOST_2', '10.0.0.3'),
        ],
    ],
    'write' => [
        'host' => [
            env('DB_WRITE_HOST', '10.0.0.1'),
        ],
    ],
    'sticky' => true, // after a write, subsequent reads use the write connection
    'driver' => 'mysql',
    'database' => env('DB_DATABASE', 'forge'),
    'username' => env('DB_USERNAME', 'forge'),
    'password' => env('DB_PASSWORD', ''),
],
```

### Sticky Sessions for Read Replicas

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

final class UserController extends Controller
{
    public function update(User $user): JsonResponse
    {
        // This write goes to the primary
        $user->update(['name' => request('name')]);

        // With sticky => true, this read also uses the primary
        // (avoids stale data from replica lag)
        $fresh = $user->fresh();

        return response()->json($fresh);
    }

    public function forceReadFromPrimary(): JsonResponse
    {
        // Explicitly use write connection for critical reads
        $count = DB::connection('mysql')->getReadPdo() === DB::connection('mysql')->getPdo()
            ? User::count()
            : DB::connection('mysql')->table('users')->count();

        return response()->json(['count' => $count]);
    }
}
```

> **Cross-reference:** See `laravel-deployment` skill for database infrastructure and replica configuration.

### Rules

- Use persistent connections to reduce connection overhead in high-traffic applications
- Use PgBouncer or ProxySQL for connection pooling in production
- Configure read/write splitting to distribute load across replicas
- Enable `sticky` sessions to prevent stale reads after writes
- Point Laravel at the connection pooler, not directly at the database
- Monitor connection pool utilization and tune `default_pool_size` based on workload

## HTTP Caching Headers

Proper HTTP caching headers dramatically reduce server load and improve response times for clients and CDNs.

### Cache-Control Header Values

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class SetCacheHeaders
{
    public function handle(Request $request, Closure $next, string $type = 'public'): Response
    {
        $response = $next($request);

        return match ($type) {
            // Public pages — cached by browsers and CDNs
            'public' => $response->header('Cache-Control', 'public, max-age=3600, s-maxage=86400'),

            // Authenticated content — only cached by the user's browser
            'private' => $response->header('Cache-Control', 'private, max-age=600, no-transform'),

            // Dynamic content — must revalidate every time
            'revalidate' => $response->header('Cache-Control', 'no-cache, must-revalidate'),

            // Sensitive data — never cache
            'none' => $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0'),

            default => $response,
        };
    }
}
```

### ETag and Last-Modified for Conditional Requests

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class ConditionalCacheMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        // Generate ETag from response content
        $etag = '"' . md5($response->getContent()) . '"';
        $response->header('ETag', $etag);

        // Return 304 Not Modified if content hasn't changed
        if ($request->header('If-None-Match') === $etag) {
            return response('', Response::HTTP_NOT_MODIFIED)
                ->header('ETag', $etag);
        }

        return $response;
    }
}
```

### Using Laravel's Built-in cache.headers Middleware

```php
// routes/web.php
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Laravel's built-in cache.headers middleware
Route::middleware('cache.headers:public;max_age=3600;etag')
    ->get('/products', [ProductController::class, 'index']);

Route::middleware('cache.headers:private;max_age=600')
    ->get('/dashboard', [DashboardController::class, 'index']);

// No caching for sensitive routes
Route::middleware('cache.headers:no_store;no_cache;must_revalidate')
    ->get('/account/settings', [AccountController::class, 'settings']);
```

### CDN Integration (Cloudflare, CloudFront)

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class CdnCacheHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        // Cloudflare-specific: cache for 1 day at edge, 1 hour in browser
        $response->headers->set('Cache-Control', 'public, max-age=3600, s-maxage=86400');

        // CloudFront: use Surrogate-Control for edge-specific caching
        $response->headers->set('Surrogate-Control', 'max-age=86400');

        // Vary header ensures correct cache per encoding/language
        $response->headers->set('Vary', 'Accept-Encoding, Accept-Language');

        return $response;
    }
}
```

### When to Cache

| Content Type | Cache Strategy | Example |
|---|---|---|
| Public pages | `public, s-maxage=86400` | Homepage, product listing |
| API responses (public) | `public, max-age=300` | Public API endpoints |
| Authenticated pages | `private, max-age=600` | User dashboard |
| Static assets | `public, max-age=31536000, immutable` | CSS, JS, images |
| Sensitive data | `no-store` | Payment info, tokens |

> **Cross-reference:** See `laravel-api` skill for API-specific caching strategies and `laravel-deployment` skill for CDN configuration.

### Rules

- Set `Cache-Control` headers on every response — never leave caching behavior undefined
- Use `s-maxage` for CDN/edge cache duration separate from browser `max-age`
- Use `private` for authenticated or user-specific content
- Use `no-store` for sensitive data (payments, personal info, tokens)
- Add `ETag` or `Last-Modified` headers for conditional request support
- Include `Vary` headers when responses differ by encoding, language, or auth state
- Use Laravel's `cache.headers` middleware for simple route-level caching

## Full-Page Caching

Cache entire HTTP responses to serve pages without hitting the application layer.

### Response Caching with spatie/laravel-responsecache

```bash
composer require spatie/laravel-responsecache
php artisan vendor:publish --provider="Spatie\ResponseCache\ResponseCacheServiceProvider"
```

```php
<?php

declare(strict_types=1);

namespace App\Http;

use Illuminate\Foundation\Http\Kernel as HttpKernel;

final class Kernel extends HttpKernel
{
    protected $middlewareGroups = [
        'web' => [
            // ... other middleware
            \Spatie\ResponseCache\Middlewares\CacheResponse::class,
        ],
    ];

    protected $routeMiddleware = [
        'doNotCacheResponse' => \Spatie\ResponseCache\Middlewares\DoNotCacheResponse::class,
    ];
}
```

```php
// routes/web.php
use Illuminate\Support\Facades\Route;

// Cached by default via global middleware
Route::get('/', [HomeController::class, 'index']);
Route::get('/products', [ProductController::class, 'index']);

// Opt out of caching for dynamic pages
Route::middleware('doNotCacheResponse')
    ->get('/checkout', [CheckoutController::class, 'index']);
```

### Cache Invalidation on Content Changes

```php
<?php

declare(strict_types=1);

namespace App\Observers;

use App\Models\Product;
use Spatie\ResponseCache\Facades\ResponseCache;

final class ProductObserver
{
    public function saved(Product $product): void
    {
        // Clear response cache when products change
        ResponseCache::clear();
    }

    public function deleted(Product $product): void
    {
        ResponseCache::clear();
    }
}
```

### Selective Cache Invalidation

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Spatie\ResponseCache\Facades\ResponseCache;

final class CacheInvalidationService
{
    /**
     * Clear cache for specific URI patterns after content changes.
     */
    public function invalidateProductPages(): void
    {
        ResponseCache::selectCachedItems()
            ->usingSuffix('products')
            ->forUrls('/products', '/products/*')
            ->forget();
    }

    /**
     * Clear all cached responses — use sparingly.
     */
    public function invalidateAll(): void
    {
        ResponseCache::clear();
    }
}
```

### Varnish / Cloudflare Page Caching Overview

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Add headers that instruct Varnish or Cloudflare to cache full pages.
 */
final class FullPageCacheHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        if ($request->isMethod('GET') && ! auth()->check()) {
            // Cache public GET requests at the edge for 24 hours
            $response->headers->set('Cache-Control', 'public, s-maxage=86400, max-age=0');
            $response->headers->set('Surrogate-Control', 'max-age=86400');
        } else {
            // Never cache authenticated or non-GET responses
            $response->headers->set('Cache-Control', 'no-store, private');
        }

        return $response;
    }
}
```

> **Cross-reference:** See `laravel-deployment` skill for Varnish/Cloudflare setup and `laravel-api` skill for API response caching patterns.

### Rules

- Use `spatie/laravel-responsecache` for application-level full-page caching
- Invalidate cached responses when underlying data changes (use model observers)
- Prefer selective invalidation over clearing the entire cache
- Never full-page cache authenticated or user-specific pages
- Combine application-level caching with CDN/edge caching for maximum performance
- Set appropriate `Surrogate-Control` headers for Varnish and CDN edge caching
- Monitor cache hit rates to ensure caching is effective
