````skill
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

````
