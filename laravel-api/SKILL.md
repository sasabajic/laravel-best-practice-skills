---
name: laravel-api
description: Laravel REST API design best practices including API Resources, API controllers, authentication with Sanctum, versioning, rate limiting, error handling, pagination, filtering, and JSON response conventions. Activates when building APIs, creating endpoints, or working with API authentication.
---

# Laravel API Best Practices

Follow these conventions when building REST APIs in Laravel.

## API Controller Convention

API controllers should be separate from web controllers. Place them in `App\Http\Controllers\Api\`.

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreOrderRequest;
use App\Http\Requests\UpdateOrderRequest;
use App\Http\Resources\OrderResource;
use App\Http\Resources\OrderCollection;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

final class OrderController extends Controller
{
    public function __construct(
        private readonly OrderService $orderService,
    ) {}

    public function index(): OrderCollection
    {
        $orders = Order::query()
            ->with(['user', 'items'])
            ->filter(request()->validated())
            ->latest()
            ->paginate(request()->integer('per_page', 15));

        return new OrderCollection($orders);
    }

    public function store(StoreOrderRequest $request): JsonResponse
    {
        $order = $this->orderService->create(
            CreateOrderData::fromRequest($request),
        );

        return OrderResource::make($order)
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(Order $order): OrderResource
    {
        return OrderResource::make($order->load(['user', 'items.product']));
    }

    public function update(UpdateOrderRequest $request, Order $order): OrderResource
    {
        $order = $this->orderService->update($order, UpdateOrderData::fromRequest($request));

        return OrderResource::make($order);
    }

    public function destroy(Order $order): JsonResponse
    {
        $this->orderService->delete($order);

        return response()->json(null, Response::HTTP_NO_CONTENT);
    }
}
```

## API Resources

**Always use API Resources** for response transformation. Never return models directly.

### Resource Convention

```php
<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

final class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'number' => $this->number,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'subtotal' => (float) $this->subtotal,
            'tax' => (float) $this->tax,
            'total' => (float) $this->total,
            'notes' => $this->notes,
            'shipped_at' => $this->shipped_at?->toIso8601String(),
            'created_at' => $this->created_at->toIso8601String(),
            'updated_at' => $this->updated_at->toIso8601String(),

            // Conditional relationships — only included when loaded
            'user' => UserResource::make($this->whenLoaded('user')),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),

            // Conditional computed values
            'items_count' => $this->whenCounted('items'),
            'items_total' => $this->whenAggregated('items', 'price', 'sum'),

            // Conditional fields based on user permissions
            'internal_notes' => $this->when(
                $request->user()?->isAdmin(),
                $this->internal_notes,
            ),
        ];
    }
}
```

### Collection Resource

```php
<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

final class OrderCollection extends ResourceCollection
{
    public $collects = OrderResource::class;

    public function toArray(Request $request): array
    {
        return [
            'data' => $this->collection,
        ];
    }

    public function with(Request $request): array
    {
        return [
            'meta' => [
                'allowed_statuses' => OrderStatus::cases(),
            ],
        ];
    }
}
```

### Resource Rules

- **One resource per model** — `UserResource`, `OrderResource`
- Use `whenLoaded()` for relationships — never assume they're loaded
- Use `when()` for conditional fields
- Cast numeric types explicitly: `(float)`, `(int)`
- Format dates consistently: `toIso8601String()`
- Include Enum values and labels
- Use `$this->whenCounted()` and `$this->whenAggregated()` for computed values

## API Routing

```php
// routes/api.php
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // Public routes
    Route::post('auth/login', [AuthController::class, 'login']);
    Route::post('auth/register', [AuthController::class, 'register']);

    // Authenticated routes
    Route::middleware('auth:sanctum')->group(function () {
        // Current user
        Route::get('me', [MeController::class, 'show']);
        Route::put('me', [MeController::class, 'update']);

        // Resources
        Route::apiResource('orders', OrderController::class);
        Route::apiResource('products', ProductController::class)->only(['index', 'show']);

        // Nested resources
        Route::apiResource('orders.items', OrderItemController::class)
            ->shallow(); // /orders/{order}/items and /items/{item}

        // Custom actions
        Route::post('orders/{order}/cancel', CancelOrderController::class)->name('orders.cancel');
        Route::post('orders/{order}/ship', ShipOrderController::class)->name('orders.ship');
    });
});
```

### Routing Rules

- Use `apiResource()` instead of `resource()` for API routes (excludes create/edit)
- Version your API: `/api/v1/`
- Use `shallow()` for nested resources
- Single-action controllers for custom actions
- Always name routes
- Group by authentication level

## API Response Format

### Consistent JSON Structure

```php
// Success — single resource
{
    "data": {
        "id": 1,
        "name": "John Doe",
        ...
    }
}

// Success — collection with pagination
{
    "data": [...],
    "links": {
        "first": "...",
        "last": "...",
        "prev": null,
        "next": "..."
    },
    "meta": {
        "current_page": 1,
        "last_page": 5,
        "per_page": 15,
        "total": 75
    }
}

// Error
{
    "message": "The given data was invalid.",
    "errors": {
        "email": ["The email has already been taken."],
        "name": ["The name field is required."]
    }
}
```

### HTTP Status Codes

Always use correct HTTP status codes:

| Code | When to Use |
|------|------------|
| `200 OK` | Successful GET, PUT, PATCH |
| `201 Created` | Successful POST that creates a resource |
| `204 No Content` | Successful DELETE |
| `400 Bad Request` | Client error, malformed request |
| `401 Unauthorized` | Missing or invalid authentication |
| `403 Forbidden` | Authenticated but not authorized |
| `404 Not Found` | Resource not found |
| `409 Conflict` | State conflict (e.g., duplicate) |
| `422 Unprocessable Entity` | Validation errors |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Server error (never expose details) |

Use Symfony constants:
```php
use Symfony\Component\HttpFoundation\Response;

Response::HTTP_OK           // 200
Response::HTTP_CREATED      // 201
Response::HTTP_NO_CONTENT   // 204
Response::HTTP_NOT_FOUND    // 404
```

## API Authentication with Sanctum

```php
// Token-based authentication
public function login(LoginRequest $request): JsonResponse
{
    $user = User::where('email', $request->email)->first();

    if (! $user || ! Hash::check($request->password, $user->password)) {
        throw ValidationException::withMessages([
            'email' => ['The provided credentials are incorrect.'],
        ]);
    }

    $token = $user->createToken(
        name: $request->device_name ?? 'api-token',
        abilities: $this->getAbilitiesForUser($user),
        expiresAt: now()->addDays(30),
    );

    return response()->json([
        'data' => [
            'user' => UserResource::make($user),
            'token' => $token->plainTextToken,
        ],
    ]);
}
```

## API Filtering & Sorting

### Query Filter Pattern

```php
// Filter class
final class OrderFilter
{
    public static function apply(Builder $query, array $filters): Builder
    {
        return $query
            ->when($filters['status'] ?? null, fn ($q, $status) => $q->where('status', $status))
            ->when($filters['search'] ?? null, fn ($q, $search) => $q->where('number', 'like', "%{$search}%"))
            ->when($filters['date_from'] ?? null, fn ($q, $date) => $q->whereDate('created_at', '>=', $date))
            ->when($filters['date_to'] ?? null, fn ($q, $date) => $q->whereDate('created_at', '<=', $date))
            ->when($filters['min_total'] ?? null, fn ($q, $min) => $q->where('total', '>=', $min))
            ->when($filters['sort'] ?? null,
                fn ($q, $sort) => $q->orderBy(
                    str($sort)->ltrim('-')->toString(),
                    str($sort)->startsWith('-') ? 'desc' : 'asc',
                ),
                fn ($q) => $q->latest(),
            );
    }
}

// In controller
Order::query()
    ->tap(fn ($q) => OrderFilter::apply($q, $request->validated()))
    ->paginate();
```

## Rate Limiting

```php
// In AppServiceProvider or RouteServiceProvider
RateLimiter::for('api', function (Request $request) {
    return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
});

RateLimiter::for('auth', function (Request $request) {
    return Limit::perMinute(5)->by($request->ip());
});
```

## API Error Handling

```php
// In bootstrap/app.php or Exception Handler
->withExceptions(function (Exceptions $exceptions) {
    $exceptions->shouldRenderJsonWhen(function (Request $request) {
        return $request->is('api/*') || $request->expectsJson();
    });

    $exceptions->render(function (ModelNotFoundException $e, Request $request) {
        if ($request->expectsJson()) {
            return response()->json([
                'message' => 'Resource not found.',
            ], Response::HTTP_NOT_FOUND);
        }
    });

    $exceptions->render(function (AuthorizationException $e, Request $request) {
        if ($request->expectsJson()) {
            return response()->json([
                'message' => 'You are not authorized to perform this action.',
            ], Response::HTTP_FORBIDDEN);
        }
    });
})
```

## API Documentation with Scramble

Use [dedoc/scramble](https://scramble.dedoc.co/) to auto-generate OpenAPI documentation from your code.

### Installation & Setup

```bash
composer require dedoc/scramble
```

### Configuration

```php
<?php

declare(strict_types=1);

// config/scramble.php
return [
    'api_path' => 'api',
    'api_domain' => null,

    // Filter which routes appear in the docs
    'routes' => fn (Route $route) => str($route->uri)->startsWith('api/v1'),
];
```

### Adding Descriptions with PHPDoc

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

final class ProductController extends Controller
{
    /**
     * List all products.
     *
     * Retrieves a paginated list of products, optionally filtered by category.
     *
     * @queryParam category string Filter by category slug. Example: electronics
     * @queryParam per_page int Number of items per page (1-100). Example: 25
     */
    public function index(): ProductResource
    {
        $products = Product::query()
            ->filter(request()->validated())
            ->paginate(request()->integer('per_page', 15));

        return ProductResource::collection($products);
    }

    /**
     * Create a new product.
     *
     * @response 201 { "data": { "id": 1, "name": "Widget", "price": 29.99 } }
     * @throws \Illuminate\Validation\ValidationException
     */
    public function store(StoreProductRequest $request): JsonResponse
    {
        $product = Product::create($request->validated());

        return ProductResource::make($product)
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }
}
```

### Custom Response Types & OpenAPI Annotations

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Dedoc\Scramble\Attributes\BodyParameter;
use Dedoc\Scramble\Attributes\HeaderParameter;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

final class ReportController extends Controller
{
    /**
     * Generate a sales report.
     *
     * Returns aggregated sales data for the given date range.
     */
    #[HeaderParameter('X-Timezone', description: 'Client timezone', example: 'America/New_York')]
    #[BodyParameter('date_from', description: 'Start date', required: true, example: '2024-01-01')]
    #[BodyParameter('date_to', description: 'End date', required: true, example: '2024-01-31')]
    public function salesReport(): JsonResponse
    {
        return response()->json([
            'data' => [
                'total_sales' => 150000.00,
                'order_count' => 1234,
                'average_order_value' => 121.55,
            ],
        ], Response::HTTP_OK);
    }
}
```

### Documentation Rules

- Install `dedoc/scramble` for automatic OpenAPI spec generation
- Add PHPDoc blocks with `@queryParam`, `@response`, and `@throws` annotations
- Use route filtering to include only public API routes in docs
- Use Scramble PHP attributes for header and body parameter metadata
- Access generated docs at `/docs/api` and the OpenAPI JSON at `/docs/api.json`
- See **laravel-testing** skill for testing API documentation accuracy

## CORS Configuration

### config/cors.php

```php
<?php

declare(strict_types=1);

// config/cors.php
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],

    'allowed_origins' => explode(',', env('CORS_ALLOWED_ORIGINS', 'https://your-frontend.com')),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],

    'exposed_headers' => ['X-RateLimit-Limit', 'X-RateLimit-Remaining', 'Retry-After'],

    'max_age' => 86400, // 24 hours — browsers cache preflight responses

    'supports_credentials' => true, // Required when using withCredentials / Sanctum SPA auth
];
```

### SPA + Sanctum CORS Considerations

```php
<?php

declare(strict_types=1);

// .env for SPA authentication with Sanctum
// SANCTUM_STATEFUL_DOMAINS=your-frontend.com,localhost:5173
// SESSION_DOMAIN=.your-domain.com
// CORS_ALLOWED_ORIGINS=https://your-frontend.com,http://localhost:5173

// config/sanctum.php
return [
    'stateful' => explode(',', env(
        'SANCTUM_STATEFUL_DOMAINS',
        'localhost,localhost:3000,localhost:5173,127.0.0.1,127.0.0.1:8000,::1',
    )),
];
```

### CORS Rules

- Always define explicit `allowed_origins` — avoid using `['*']` in production
- Set `supports_credentials` to `true` only when using cookie-based SPA authentication
- Include `sanctum/csrf-cookie` in `paths` when using Sanctum SPA authentication
- Expose rate-limit headers so clients can handle `429` responses gracefully
- Keep `max_age` high (e.g., `86400`) to reduce preflight requests
- See **laravel-security** skill for additional security hardening guidelines

## Webhook Handling

### Webhook Controller Pattern

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\Webhooks;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessStripeWebhookJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

final class StripeWebhookController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $payload = $request->getContent();
        $sigHeader = $request->header('Stripe-Signature', '');

        if (! $this->verifySignature($payload, $sigHeader)) {
            Log::warning('Stripe webhook signature verification failed.', [
                'ip' => $request->ip(),
            ]);

            return response()->json(
                ['message' => 'Invalid signature.'],
                Response::HTTP_FORBIDDEN,
            );
        }

        $event = json_decode($payload, true, 512, JSON_THROW_ON_ERROR);

        Log::info('Stripe webhook received.', [
            'type' => $event['type'],
            'id' => $event['id'],
        ]);

        ProcessStripeWebhookJob::dispatch($event)
            ->onQueue('webhooks');

        return response()->json(
            ['message' => 'Webhook received.'],
            Response::HTTP_OK,
        );
    }

    private function verifySignature(string $payload, string $sigHeader): bool
    {
        try {
            \Stripe\Webhook::constructEvent(
                $payload,
                $sigHeader,
                config('services.stripe.webhook_secret'),
            );

            return true;
        } catch (\Stripe\Exception\SignatureVerificationException) {
            return false;
        }
    }
}
```

### Idempotent Webhook Processing

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\WebhookEvent;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

final class ProcessStripeWebhookJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public int $backoff = 60;

    public function __construct(
        private readonly array $event,
    ) {}

    public function handle(): void
    {
        // Idempotency — prevent duplicate processing
        $webhookEvent = WebhookEvent::firstOrCreate(
            ['provider_event_id' => $this->event['id']],
            [
                'provider' => 'stripe',
                'type' => $this->event['type'],
                'payload' => $this->event,
            ],
        );

        if ($webhookEvent->wasRecentlyCreated === false) {
            Log::info('Duplicate webhook skipped.', ['id' => $this->event['id']]);

            return;
        }

        match ($this->event['type']) {
            'payment_intent.succeeded' => $this->handlePaymentSucceeded(),
            'invoice.paid' => $this->handleInvoicePaid(),
            'customer.subscription.deleted' => $this->handleSubscriptionCancelled(),
            default => Log::info('Unhandled webhook type.', ['type' => $this->event['type']]),
        };

        $webhookEvent->update(['processed_at' => now()]);
    }

    private function handlePaymentSucceeded(): void
    {
        // Process the successful payment
    }

    private function handleInvoicePaid(): void
    {
        // Process the paid invoice
    }

    private function handleSubscriptionCancelled(): void
    {
        // Handle subscription cancellation
    }
}
```

### Webhook Route Registration

```php
// routes/api.php
use App\Http\Controllers\Api\Webhooks\StripeWebhookController;

// Webhooks — no auth middleware, no CSRF, no rate limiting
Route::post('webhooks/stripe', StripeWebhookController::class)
    ->name('webhooks.stripe')
    ->withoutMiddleware(['throttle:api']);
```

### Webhook Rules

- Always verify webhook signatures before processing payloads
- Dispatch webhook processing to a queue — return `200` immediately
- Use idempotency keys (`provider_event_id`) to prevent duplicate processing
- Log all incoming webhook payloads for debugging and auditing
- Exclude webhook routes from CSRF, authentication, and aggressive rate limiting
- Store raw payloads in a `webhook_events` table for replay and troubleshooting
- See **laravel-security** skill for signature verification patterns and **laravel-testing** skill for testing webhook endpoints

## Bulk Operations

### Bulk Create Endpoint

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\BulkCreateProductsRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

final class BulkProductController extends Controller
{
    /**
     * Create multiple products in a single request.
     */
    public function store(BulkCreateProductsRequest $request): JsonResponse
    {
        $results = DB::transaction(function () use ($request): array {
            $created = [];

            foreach ($request->validated('products') as $productData) {
                $created[] = Product::create($productData);
            }

            return $created;
        });

        return response()->json([
            'data' => ProductResource::collection($results),
            'meta' => [
                'total_created' => count($results),
            ],
        ], Response::HTTP_CREATED);
    }
}
```

### Bulk Request Validation

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class BulkCreateProductsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Product::class);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'products' => ['required', 'array', 'min:1', 'max:100'],
            'products.*.name' => ['required', 'string', 'max:255'],
            'products.*.sku' => ['required', 'string', 'unique:products,sku'],
            'products.*.price' => ['required', 'numeric', 'min:0'],
            'products.*.category_id' => ['required', 'exists:categories,id'],
        ];
    }
}
```

### Bulk Update / Delete with Partial Success

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\BulkUpdateProductsRequest;
use App\Http\Requests\BulkDeleteProductsRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

final class BulkProductOperationController extends Controller
{
    /**
     * Update multiple products. Supports partial success.
     */
    public function update(BulkUpdateProductsRequest $request): JsonResponse
    {
        $succeeded = [];
        $failed = [];

        DB::transaction(function () use ($request, &$succeeded, &$failed): void {
            foreach ($request->validated('products') as $item) {
                try {
                    $product = Product::findOrFail($item['id']);
                    $product->update($item);
                    $succeeded[] = ProductResource::make($product)->resolve();
                } catch (\Throwable $e) {
                    Log::warning('Bulk update failed for product.', [
                        'id' => $item['id'] ?? null,
                        'error' => $e->getMessage(),
                    ]);

                    $failed[] = [
                        'id' => $item['id'] ?? null,
                        'error' => 'Failed to update product.',
                    ];
                }
            }
        });

        return response()->json([
            'data' => [
                'succeeded' => $succeeded,
                'failed' => $failed,
            ],
            'meta' => [
                'total_succeeded' => count($succeeded),
                'total_failed' => count($failed),
            ],
        ], count($failed) > 0 ? Response::HTTP_MULTI_STATUS : Response::HTTP_OK);
    }

    /**
     * Delete multiple products by ID.
     */
    public function destroy(BulkDeleteProductsRequest $request): JsonResponse
    {
        $ids = $request->validated('ids');

        $deletedCount = Product::whereIn('id', $ids)->delete();

        return response()->json([
            'meta' => [
                'total_requested' => count($ids),
                'total_deleted' => $deletedCount,
            ],
        ], Response::HTTP_OK);
    }
}
```

### Bulk Operations Rules

- Limit batch size in validation (e.g., `max:100`) to prevent abuse
- Wrap bulk writes in `DB::transaction()` for atomicity when full rollback is desired
- Return `207 Multi-Status` when some operations succeed and others fail
- Include `succeeded` and `failed` arrays with per-item detail in the response
- Validate each item in the array using Laravel's `products.*` wildcard notation
- Log failures individually for troubleshooting
- See **laravel-security** skill for authorization on bulk endpoints and **laravel-testing** skill for testing bulk operations

## API Versioning Strategies

### URL Prefix Versioning (Recommended)

```php
<?php

declare(strict_types=1);

// routes/api.php — preferred approach
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->as('v1.')->group(function () {
    Route::apiResource('orders', App\Http\Controllers\Api\V1\OrderController::class);
    Route::apiResource('products', App\Http\Controllers\Api\V1\ProductController::class);
});

Route::prefix('v2')->as('v2.')->group(function () {
    Route::apiResource('orders', App\Http\Controllers\Api\V2\OrderController::class);
    Route::apiResource('products', App\Http\Controllers\Api\V2\ProductController::class);
});
```

### Versioned Controller Organization

```
app/Http/Controllers/Api/
├── V1/
│   ├── OrderController.php
│   └── ProductController.php
└── V2/
    ├── OrderController.php
    └── ProductController.php
```

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V2;

use App\Http\Controllers\Controller;
use App\Http\Resources\V2\OrderResource;
use App\Models\Order;

final class OrderController extends Controller
{
    public function index(): \Illuminate\Http\Resources\Json\AnonymousResourceCollection
    {
        $orders = Order::query()
            ->with(['user', 'items.product'])
            ->latest()
            ->paginate(request()->integer('per_page', 25));

        return OrderResource::collection($orders);
    }

    public function show(Order $order): OrderResource
    {
        return OrderResource::make($order->load(['user', 'items.product']));
    }
}
```

### Header-Based Versioning

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class ApiVersionMiddleware
{
    /** @var array<string, string> */
    private const VERSION_NAMESPACE_MAP = [
        'v1' => 'App\\Http\\Controllers\\Api\\V1',
        'v2' => 'App\\Http\\Controllers\\Api\\V2',
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $version = $request->header('X-API-Version', 'v1');

        if (! array_key_exists($version, self::VERSION_NAMESPACE_MAP)) {
            return response()->json([
                'message' => "Unsupported API version: {$version}.",
            ], Response::HTTP_BAD_REQUEST);
        }

        $request->attributes->set('api_version', $version);

        return $next($request);
    }
}
```

### Deprecation Headers

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class DeprecatedApiVersionMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        /** @var Response $response */
        $response = $next($request);

        $response->headers->set('Deprecation', 'true');
        $response->headers->set('Sunset', 'Sat, 01 Mar 2025 00:00:00 GMT');
        $response->headers->set('Link', '<https://api.example.com/v2>; rel="successor-version"');

        return $response;
    }
}
```

### Applying Deprecation to v1 Routes

```php
// routes/api.php
Route::prefix('v1')
    ->as('v1.')
    ->middleware(['deprecated-api'])
    ->group(function () {
        Route::apiResource('orders', App\Http\Controllers\Api\V1\OrderController::class);
    });
```

### Versioning Rules

- Use URL prefix versioning (`/api/v1/`) as the default strategy — it is explicit and easy to route
- Organize controllers and resources under versioned namespaces (`Api\V1`, `Api\V2`)
- Share models, services, and business logic across versions — only controllers and resources differ
- Add `Deprecation`, `Sunset`, and `Link` headers to sunset older API versions
- Never remove a published version without a deprecation period and client notification
- Prefer creating a new version over introducing breaking changes to an existing one
- See **laravel-security** skill for per-version rate limiting and **laravel-testing** skill for testing multiple API versions
