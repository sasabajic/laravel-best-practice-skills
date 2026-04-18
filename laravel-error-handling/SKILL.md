---
name: laravel-error-handling
description: Laravel exception handling and error management best practices including custom exceptions, exception handler configuration, error reporting, error pages, Sentry/Bugsnag integration, logging strategies, and graceful degradation. Activates when working with exceptions, error handling, logging, or error pages.
---

# Laravel Error Handling Best Practices

> Consistent, structured error handling prevents information leakage, improves debugging, and delivers a professional user experience. These patterns apply to Laravel 10+ with version-specific notes where syntax differs.

## Exception Handler Configuration

### Laravel 11+ (bootstrap/app.php)

Laravel 11 configures exception handling via the application bootstrap file:

```php
<?php

// bootstrap/app.php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use App\Exceptions\DomainException;
use App\Exceptions\PaymentFailedException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Don't report certain exceptions
        $exceptions->dontReport([
            DomainException::class,
        ]);

        // Custom reporting
        $exceptions->report(function (PaymentFailedException $e): void {
            // Send to external service
        });

        // Custom rendering
        $exceptions->render(function (PaymentFailedException $e) {
            return response()->json([
                'message' => $e->getMessage(),
                'code' => $e->getErrorCode(),
            ], $e->getStatusCode());
        });
    })->create();
```

### Laravel 10 (app/Exceptions/Handler.php)

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Throwable;

final class Handler extends ExceptionHandler
{
    /** @var list<class-string<Throwable>> */
    protected $dontReport = [
        \App\Exceptions\DomainException::class,
    ];

    public function register(): void
    {
        $this->reportable(function (PaymentFailedException $e): void {
            // Custom reporting logic
        });
    }
}
```

## Custom Exception Classes

### Naming & Structure Convention

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use RuntimeException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

// GOOD — Domain exception with HTTP awareness, typed properties, and self-rendering
final class InsufficientBalanceException extends RuntimeException implements HttpExceptionInterface
{
    public function __construct(
        private readonly float $currentBalance,
        private readonly float $requiredAmount,
    ) {
        parent::__construct(
            message: sprintf(
                'Insufficient balance: have %.2f, need %.2f',
                $currentBalance,
                $requiredAmount,
            ),
            code: 0,
            previous: null,
        );
    }

    public function getStatusCode(): int
    {
        return 422;
    }

    public function getHeaders(): array
    {
        return [];
    }

    public function context(): array
    {
        return [
            'current_balance' => $this->currentBalance,
            'required_amount' => $this->requiredAmount,
        ];
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use Exception;

// BAD — No typed properties, no context, generic message
class BalanceError extends Exception
{
    public function __construct()
    {
        parent::__construct('Something went wrong');
    }
}
```

### HTTP Exception Shortcuts

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

// GOOD — Semantic exception wrapping the HTTP layer
final class OrderNotFoundException extends NotFoundHttpException
{
    public function __construct(int|string $orderId)
    {
        parent::__construct(
            message: sprintf('Order [%s] not found.', $orderId),
        );
    }
}
```

## Domain vs Infrastructure Exceptions

Separate business-logic exceptions from infrastructure failures. This keeps your domain layer clean and lets the exception handler apply different strategies.

| Type | Base Class | Example | Reporting |
|------|-----------|---------|-----------|
| Domain / Business | `RuntimeException` | `InsufficientBalanceException` | Usually not reported to Sentry |
| Infrastructure | `RuntimeException` | `PaymentGatewayUnavailableException` | Always report — indicates system failure |
| Validation | `ValidationException` | Laravel's built-in | Handled automatically by framework |
| Authorization | `AuthorizationException` | Laravel's built-in | Handled automatically by framework |

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use RuntimeException;

// Domain exception — expected, user-correctable
final class InvalidCouponException extends RuntimeException
{
    public function __construct(public readonly string $couponCode)
    {
        parent::__construct("Coupon '{$couponCode}' is not valid.");
    }

    public function report(): false
    {
        // Returning false prevents reporting to logs/Sentry
        return false;
    }

    public function render(): \Illuminate\Http\JsonResponse
    {
        return response()->json([
            'message' => $this->getMessage(),
            'error' => 'invalid_coupon',
        ], 422);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use RuntimeException;

// Infrastructure exception — unexpected, not user-correctable
final class PaymentGatewayUnavailableException extends RuntimeException
{
    public function __construct(string $gateway, ?\Throwable $previous = null)
    {
        parent::__construct(
            message: "Payment gateway [{$gateway}] is unavailable.",
            previous: $previous,
        );
    }

    public function context(): array
    {
        return [
            'gateway' => $this->getMessage(),
            'previous' => $this->getPrevious()?->getMessage(),
        ];
    }
}
```

## Exception Reporting — Sentry & Bugsnag Integration

### Sentry Setup

```php
<?php

// bootstrap/app.php (Laravel 11+)

use Illuminate\Foundation\Configuration\Exceptions;

->withExceptions(function (Exceptions $exceptions): void {
    $exceptions->report(function (Throwable $e): void {
        if (app()->bound('sentry') && $this->shouldReport($e)) {
            app('sentry')->captureException($e);
        }
    });
})
```

### Bugsnag Setup

```php
<?php

// bootstrap/app.php (Laravel 11+)

use Illuminate\Foundation\Configuration\Exceptions;

->withExceptions(function (Exceptions $exceptions): void {
    $exceptions->report(function (Throwable $e): void {
        if (app()->bound('bugsnag')) {
            app('bugsnag')->notifyException($e);
        }
    });
})
```

### Contextual Reporting

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use RuntimeException;

// GOOD — Rich context for debugging in Sentry/Bugsnag
final class OrderProcessingException extends RuntimeException
{
    public function __construct(
        private readonly int $orderId,
        private readonly string $step,
        ?\Throwable $previous = null,
    ) {
        parent::__construct(
            message: "Failed to process order [{$orderId}] at step [{$step}].",
            previous: $previous,
        );
    }

    /** Automatically merged into the log/Sentry context. */
    public function context(): array
    {
        return [
            'order_id' => $this->orderId,
            'step' => $this->step,
            'user_id' => auth()->id(),
        ];
    }
}
```

> **Cross-reference:** See the **laravel-security** skill for ensuring sensitive data is never leaked through exception messages or context arrays.

## Exception Rendering — JSON vs HTML

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

// GOOD — Self-rendering exception that respects content negotiation
final class RateLimitExceededException extends RuntimeException
{
    public function __construct(
        private readonly int $retryAfterSeconds = 60,
    ) {
        parent::__construct('Too many requests. Please try again later.');
    }

    public function render(Request $request): JsonResponse|\Illuminate\Http\Response
    {
        if ($request->expectsJson()) {
            return response()->json([
                'message' => $this->getMessage(),
                'retry_after' => $this->retryAfterSeconds,
            ], 429)->withHeaders([
                'Retry-After' => $this->retryAfterSeconds,
            ]);
        }

        return response()->view('errors.429', [
            'retryAfter' => $this->retryAfterSeconds,
        ], 429);
    }
}
```

> **Cross-reference:** See the **laravel-api** skill for consistent API error response envelope formatting and HTTP status code conventions.

## Don't Report — Ignorable Exceptions

Not every exception deserves a log entry or a Sentry alert. Suppress exceptions that are expected during normal operation.

```php
<?php

// bootstrap/app.php (Laravel 11+)

use App\Exceptions\InvalidCouponException;
use App\Exceptions\InsufficientBalanceException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

->withExceptions(function (Exceptions $exceptions): void {
    // These are user-correctable or expected — don't flood your logs
    $exceptions->dontReport([
        InvalidCouponException::class,
        InsufficientBalanceException::class,
    ]);

    // Laravel already ignores these by default:
    // - AuthenticationException
    // - AuthorizationException
    // - ValidationException
    // - NotFoundHttpException
    // - ModelNotFoundException (converted to 404)
    // - TokenMismatchException
})
```

## Custom Error Pages

Place Blade views in `resources/views/errors/` to override default error pages.

```
resources/views/errors/
├── 401.blade.php
├── 403.blade.php
├── 404.blade.php
├── 419.blade.php
├── 429.blade.php
├── 500.blade.php
└── 503.blade.php
```

```blade
{{-- resources/views/errors/404.blade.php --}}
@extends('errors::minimal')

@section('title', __('Not Found'))
@section('code', '404')
@section('message', __('The page you are looking for could not be found.'))
```

```blade
{{-- resources/views/errors/500.blade.php --}}
@extends('errors::minimal')

@section('title', __('Server Error'))
@section('code', '500')
@section('message', __('Something went wrong on our end. We have been notified.'))
```

To publish Laravel's default error page layout for customization:

```bash
php artisan vendor:publish --tag=laravel-errors
```

## Logging Strategy

### Channel Configuration

```php
<?php

// config/logging.php — GOOD structured multi-channel setup

return [
    'default' => env('LOG_CHANNEL', 'stack'),

    'channels' => [
        'stack' => [
            'driver' => 'stack',
            'channels' => ['daily', 'stderr'],
            'ignore_exceptions' => false,
        ],

        'daily' => [
            'driver' => 'daily',
            'path' => storage_path('logs/laravel.log'),
            'level' => env('LOG_LEVEL', 'debug'),
            'days' => 14,
            'replace_placeholders' => true,
        ],

        'stderr' => [
            'driver' => 'monolog',
            'level' => env('LOG_LEVEL', 'debug'),
            'handler' => \Monolog\Handler\StreamHandler::class,
            'with' => [
                'stream' => 'php://stderr',
            ],
            'formatter' => env('LOG_STDERR_FORMATTER'),
        ],

        // Dedicated channel for payment events
        'payments' => [
            'driver' => 'daily',
            'path' => storage_path('logs/payments.log'),
            'level' => 'info',
            'days' => 30,
        ],
    ],
];
```

### Structured Logging with Context

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Log;

final class PaymentService
{
    // GOOD — Structured context, specific channel, appropriate level
    public function charge(int $orderId, float $amount): void
    {
        Log::channel('payments')->info('Payment initiated', [
            'order_id' => $orderId,
            'amount' => $amount,
            'currency' => 'USD',
            'user_id' => auth()->id(),
        ]);

        try {
            // ... payment logic
        } catch (\Stripe\Exception\CardException $e) {
            Log::channel('payments')->warning('Payment declined', [
                'order_id' => $orderId,
                'decline_code' => $e->getDeclineCode(),
                'user_id' => auth()->id(),
            ]);

            throw new \App\Exceptions\PaymentDeclinedException($orderId, $e);
        } catch (\Throwable $e) {
            Log::channel('payments')->error('Payment failed unexpectedly', [
                'order_id' => $orderId,
                'exception' => $e::class,
                'message' => $e->getMessage(),
            ]);

            throw new \App\Exceptions\PaymentGatewayUnavailableException('stripe', $e);
        }
    }

    // BAD — Unstructured string concatenation, no context, wrong level
    public function chargeBad(int $orderId, float $amount): void
    {
        Log::debug('charging ' . $orderId . ' for ' . $amount);

        try {
            // ...
        } catch (\Exception $e) {
            Log::info('payment error: ' . $e->getMessage());
        }
    }
}
```

## Try/Catch Best Practices

### When to Catch

```php
<?php

declare(strict_types=1);

namespace App\Services;

// GOOD — Catch only when you can meaningfully handle the error
final class ImportService
{
    public function importRow(array $row): ImportResult
    {
        try {
            $this->validate($row);
            $this->persist($row);

            return ImportResult::success($row);
        } catch (\App\Exceptions\InvalidRowException $e) {
            // We can handle this — skip the row and continue the batch
            return ImportResult::skipped($row, $e->getMessage());
        }
        // Let other exceptions bubble up to the global handler
    }
}
```

### When to Let Bubble

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class OrderController extends Controller
{
    // GOOD — No try/catch needed; let the exception handler deal with it
    public function store(Request $request, OrderService $orderService): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => ['required', 'exists:products,id'],
            'quantity' => ['required', 'integer', 'min:1'],
        ]);

        $order = $orderService->create($validated);

        return response()->json($order, 201);
    }

    // BAD — Catching everything, swallowing context, returning misleading response
    public function storeBad(Request $request, OrderService $orderService): JsonResponse
    {
        try {
            $validated = $request->validate([
                'product_id' => ['required', 'exists:products,id'],
                'quantity' => ['required', 'integer', 'min:1'],
            ]);

            $order = $orderService->create($validated);

            return response()->json($order, 201);
        } catch (\Exception $e) {
            return response()->json(['error' => 'Something went wrong'], 500);
        }
    }
}
```

## Graceful Degradation Patterns

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

// GOOD — Fallback to cache when external service is unavailable
final class ExchangeRateService
{
    public function __construct(
        private readonly ExchangeRateApiClient $client,
    ) {}

    public function getRate(string $from, string $to): float
    {
        try {
            $rate = $this->client->fetchRate($from, $to);
            Cache::put("exchange_rate:{$from}:{$to}", $rate, now()->addHour());

            return $rate;
        } catch (\App\Exceptions\ExternalServiceException $e) {
            Log::warning('Exchange rate API unavailable, falling back to cache', [
                'from' => $from,
                'to' => $to,
                'error' => $e->getMessage(),
            ]);

            $cached = Cache::get("exchange_rate:{$from}:{$to}");

            if ($cached === null) {
                throw new \App\Exceptions\ExchangeRateUnavailableException($from, $to, $e);
            }

            return (float) $cached;
        }
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Log;

// GOOD — Circuit-breaker style: fail fast after repeated failures
final class NotificationService
{
    private const MAX_FAILURES = 3;
    private const COOLDOWN_SECONDS = 300;

    public function send(string $channel, string $message): bool
    {
        $failureKey = "notification_failures:{$channel}";

        if ((int) cache($failureKey, 0) >= self::MAX_FAILURES) {
            Log::warning('Notification channel circuit open, skipping', [
                'channel' => $channel,
            ]);

            return false;
        }

        try {
            $this->dispatch($channel, $message);

            return true;
        } catch (\Throwable $e) {
            cache()->increment($failureKey);
            cache()->put($failureKey, (int) cache($failureKey, 0), now()->addSeconds(self::COOLDOWN_SECONDS));

            Log::error('Notification delivery failed', [
                'channel' => $channel,
                'exception' => $e::class,
            ]);

            return false;
        }
    }

    private function dispatch(string $channel, string $message): void
    {
        // ...
    }
}
```

## Abort Helpers

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Order;
use Illuminate\Http\JsonResponse;

final class OrderController extends Controller
{
    // GOOD — Semantic abort helpers for guard clauses
    public function show(int $id): JsonResponse
    {
        $order = Order::find($id);

        abort_if($order === null, 404, 'Order not found.');
        abort_unless($order->user_id === auth()->id(), 403, 'Access denied.');

        return response()->json($order);
    }

    // BAD — Manual if/throw when abort helpers are cleaner
    public function showBad(int $id): JsonResponse
    {
        $order = Order::find($id);

        if (! $order) {
            throw new \Symfony\Component\HttpKernel\Exception\NotFoundHttpException('Order not found.');
        }

        if ($order->user_id !== auth()->id()) {
            throw new \Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException();
        }

        return response()->json($order);
    }
}
```

> **Tip:** Prefer `abort_if()` / `abort_unless()` for simple guard clauses in controllers. Use custom exceptions when you need richer context or domain semantics.

## Testing Exception Handling

```php
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Exceptions\InsufficientBalanceException;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

// GOOD — Test that the correct exception is thrown and the response is formatted properly
final class WalletWithdrawalTest extends TestCase
{
    use RefreshDatabase;

    public function test_withdrawal_exceeding_balance_returns_422(): void
    {
        $user = User::factory()->create();
        Wallet::factory()->for($user)->create(['balance' => 50.00]);

        $response = $this->actingAs($user)
            ->postJson('/api/wallet/withdraw', [
                'amount' => 100.00,
            ]);

        $response->assertStatus(422)
            ->assertJson([
                'message' => 'Insufficient balance: have 50.00, need 100.00',
            ]);
    }

    public function test_withdrawal_exceeding_balance_throws_domain_exception(): void
    {
        $this->expectException(InsufficientBalanceException::class);

        $user = User::factory()->create();
        $wallet = Wallet::factory()->for($user)->create(['balance' => 50.00]);

        $wallet->withdraw(100.00);
    }

    public function test_server_error_does_not_leak_internals(): void
    {
        // Simulate an unexpected error and verify no stack trace leaks
        $this->mock(\App\Services\PaymentService::class, function ($mock): void {
            $mock->shouldReceive('charge')
                ->andThrow(new \RuntimeException('DB connection refused'));
        });

        $response = $this->postJson('/api/orders', [
            'product_id' => 1,
            'quantity' => 1,
        ]);

        $response->assertStatus(500)
            ->assertJsonMissing(['exception', 'trace', 'file', 'line']);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Exceptions\PaymentGatewayUnavailableException;
use App\Services\ExchangeRateService;
use Illuminate\Support\Facades\Cache;
use PHPUnit\Framework\TestCase;

// GOOD — Test graceful degradation fallback
final class ExchangeRateServiceTest extends TestCase
{
    public function test_falls_back_to_cached_rate_when_api_unavailable(): void
    {
        Cache::shouldReceive('put')->once();
        Cache::shouldReceive('get')
            ->with('exchange_rate:USD:EUR')
            ->andReturn(0.85);

        $client = $this->createMock(\App\Services\ExchangeRateApiClient::class);
        $client->method('fetchRate')
            ->willThrowException(new \App\Exceptions\ExternalServiceException('timeout'));

        $service = new ExchangeRateService($client);

        $rate = $service->getRate('USD', 'EUR');

        $this->assertSame(0.85, $rate);
    }
}
```

> **Cross-reference:** See the **laravel-testing** skill for full patterns on testing services, HTTP responses, and mocking.

## Quick Reference — Log Levels

| Level | When to Use | Example |
|-------|------------|---------|
| `emergency` | System is unusable | Database server unreachable |
| `alert` | Immediate action required | Disk space critical |
| `critical` | Critical conditions | Payment processor down |
| `error` | Runtime errors | Failed API call to third-party |
| `warning` | Exceptional but handled | Cache fallback used |
| `notice` | Normal but significant | User login from new IP |
| `info` | Informational | Order placed, email sent |
| `debug` | Debug information | SQL query, request payload |

## Summary of Rules

1. **ALWAYS** use `declare(strict_types=1)` and `final` on exception classes.
2. **ALWAYS** provide a `context()` method on exceptions that carry domain data.
3. **NEVER** catch `\Exception` or `\Throwable` in controllers — let the handler manage it.
4. **NEVER** expose stack traces, file paths, or internal messages in production responses.
5. **Separate** domain exceptions (user-correctable) from infrastructure exceptions (system failures).
6. **Use** structured logging with context arrays — never string concatenation.
7. **Use** dedicated log channels for important subsystems (payments, imports, notifications).
8. **Test** both the exception throwing and the rendered HTTP response.
9. **Configure** external error tracking (Sentry/Bugsnag) for infrastructure exceptions only.
10. **Implement** graceful degradation with cache fallbacks and circuit-breaker patterns.
