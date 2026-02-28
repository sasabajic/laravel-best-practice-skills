````skill
---
name: laravel-testing
description: Laravel testing best practices using Pest PHP and PHPUnit including feature tests, unit tests, model factories, test organization, assertions, mocking, database testing, API testing, and test-driven development workflows.
---

# Laravel Testing Best Practices

Follow these testing conventions and strategies in all Laravel projects. **Prefer Pest PHP** over raw PHPUnit for cleaner, more expressive tests.

## Testing Stack

- **Pest PHP** — primary test framework (expressive, minimal boilerplate)
- **PHPUnit** — underlying engine (Pest runs on top of it)
- **Laravel's built-in testing tools** — HTTP tests, database assertions, fakes
- **Faker** — test data generation via factories

## Test Organization

```
tests/
├── Feature/                   # Integration/feature tests (HTTP, full stack)
│   ├── Api/
│   │   ├── AuthTest.php
│   │   ├── OrderTest.php
│   │   └── UserTest.php
│   ├── Console/
│   │   └── PruneOldOrdersTest.php
│   ├── Jobs/
│   │   └── ProcessPaymentTest.php
│   └── Mail/
│       └── WelcomeEmailTest.php
├── Unit/                      # Pure unit tests (no framework booting)
│   ├── Actions/
│   │   └── CalculateDiscountTest.php
│   ├── DTOs/
│   │   └── CreateUserDataTest.php
│   ├── Enums/
│   │   └── OrderStatusTest.php
│   └── Services/
│       └── PricingServiceTest.php
├── Pest.php                   # Pest configuration
└── TestCase.php               # Base test case
```

## Pest Configuration

```php
// tests/Pest.php
<?php

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;

// Feature tests use the full Laravel application + database
pest()->extend(TestCase::class)
    ->use(LazilyRefreshDatabase::class)
    ->in('Feature');

// Unit tests — no framework
pest()->extend(TestCase::class)
    ->in('Unit');
```

## Feature Test Examples (Pest)

### API Endpoint Tests

```php
<?php

use App\Models\User;
use App\Models\Order;
use App\Enums\OrderStatus;

describe('Orders API', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        $this->actingAs($this->user, 'sanctum');
    });

    describe('GET /api/v1/orders', function () {
        it('returns paginated orders for authenticated user', function () {
            Order::factory()
                ->count(20)
                ->for($this->user)
                ->create();

            $response = $this->getJson('/api/v1/orders?per_page=10');

            $response
                ->assertOk()
                ->assertJsonCount(10, 'data')
                ->assertJsonStructure([
                    'data' => [['id', 'number', 'status', 'total', 'created_at']],
                    'meta' => ['current_page', 'last_page', 'per_page', 'total'],
                    'links',
                ]);
        });

        it('filters orders by status', function () {
            Order::factory()->for($this->user)->create(['status' => OrderStatus::Pending]);
            Order::factory()->for($this->user)->create(['status' => OrderStatus::Shipped]);

            $response = $this->getJson('/api/v1/orders?status=pending');

            $response
                ->assertOk()
                ->assertJsonCount(1, 'data')
                ->assertJsonPath('data.0.status', 'pending');
        });

        it('returns 401 for unauthenticated request', function () {
            // Reset authentication
            $this->app['auth']->forgetGuards();

            $this->getJson('/api/v1/orders')
                ->assertUnauthorized();
        });
    });

    describe('POST /api/v1/orders', function () {
        it('creates an order with valid data', function () {
            $data = [
                'items' => [
                    ['product_id' => 1, 'quantity' => 2],
                    ['product_id' => 3, 'quantity' => 1],
                ],
                'notes' => 'Please wrap as gift',
            ];

            $response = $this->postJson('/api/v1/orders', $data);

            $response
                ->assertCreated()
                ->assertJsonStructure(['data' => ['id', 'number', 'status', 'total']]);

            $this->assertDatabaseHas('orders', [
                'user_id' => $this->user->id,
                'status' => OrderStatus::Pending->value,
            ]);
        });

        it('returns validation errors for invalid data', function () {
            $response = $this->postJson('/api/v1/orders', []);

            $response
                ->assertUnprocessable()
                ->assertJsonValidationErrors(['items']);
        });
    });

    describe('PUT /api/v1/orders/{order}', function () {
        it('updates an order', function () {
            $order = Order::factory()->for($this->user)->create();

            $response = $this->putJson("/api/v1/orders/{$order->id}", [
                'notes' => 'Updated notes',
            ]);

            $response->assertOk();
            expect($order->fresh()->notes)->toBe('Updated notes');
        });

        it('returns 403 when user does not own the order', function () {
            $otherUser = User::factory()->create();
            $order = Order::factory()->for($otherUser)->create();

            $this->putJson("/api/v1/orders/{$order->id}", ['notes' => 'Hack'])
                ->assertForbidden();
        });
    });

    describe('DELETE /api/v1/orders/{order}', function () {
        it('deletes an order', function () {
            $order = Order::factory()->for($this->user)->create();

            $this->deleteJson("/api/v1/orders/{$order->id}")
                ->assertNoContent();

            $this->assertSoftDeleted('orders', ['id' => $order->id]);
        });
    });
});
```

### Using Pest Expectations (prefer over PHPUnit assertions)

```php
// Pest's expect() API — cleaner and more readable
it('calculates order total correctly', function () {
    $order = Order::factory()
        ->has(OrderItem::factory()->count(3)->state(['price' => 10.00]))
        ->create();

    expect($order->fresh())
        ->total->toBe(30.00)
        ->items->toHaveCount(3)
        ->status->toBe(OrderStatus::Pending)
        ->isPending()->toBeTrue()
        ->user_id->toBeInt()
        ->created_at->not->toBeNull();
});

// Chain expectations
it('creates a user with correct attributes', function () {
    $user = User::factory()->admin()->create();

    expect($user)
        ->toBeInstanceOf(User::class)
        ->name->not->toBeEmpty()
        ->email->toContain('@')
        ->role->toBe(UserRole::Admin)
        ->and($user->orders)->toBeEmpty();
});
```

## Unit Test Examples

```php
<?php

use App\Actions\CalculateDiscount;
use App\DTOs\CreateUserData;
use App\Enums\OrderStatus;

describe('CalculateDiscount', function () {
    it('applies percentage discount', function () {
        $calculator = new CalculateDiscount();

        $result = $calculator->execute(amount: 100.00, discountPercent: 10);

        expect($result)->toBe(90.00);
    });

    it('does not allow negative totals', function () {
        $calculator = new CalculateDiscount();

        $result = $calculator->execute(amount: 5.00, discountPercent: 100);

        expect($result)->toBe(0.00);
    });

    it('throws for invalid discount percentage', function () {
        $calculator = new CalculateDiscount();

        expect(fn () => $calculator->execute(amount: 100, discountPercent: -10))
            ->toThrow(InvalidArgumentException::class);
    });
});

describe('OrderStatus Enum', function () {
    it('has correct labels', function () {
        expect(OrderStatus::Pending->label())->toBe('Pending');
        expect(OrderStatus::Shipped->label())->toBe('Shipped');
    });

    it('provides all cases', function () {
        expect(OrderStatus::cases())->toHaveCount(5);
    });
});

describe('CreateUserData DTO', function () {
    it('creates from array', function () {
        $data = CreateUserData::fromArray([
            'name' => 'John',
            'email' => 'john@example.com',
            'password' => 'secret',
        ]);

        expect($data)
            ->name->toBe('John')
            ->email->toBe('john@example.com')
            ->phone->toBeNull();
    });
});
```

## Testing Patterns

### Use Factories Effectively

```php
// States for different scenarios
$admin = User::factory()->admin()->create();
$unverified = User::factory()->unverified()->create();
$withOrders = User::factory()->has(Order::factory()->count(5))->create();

// Override specific attributes
$user = User::factory()->create(['email' => 'specific@example.com']);

// Sequences for varied data
$users = User::factory()
    ->count(3)
    ->sequence(
        ['role' => UserRole::Admin],
        ['role' => UserRole::Editor],
        ['role' => UserRole::Viewer],
    )
    ->create();
```

### Use Fakes for External Services

```php
it('sends welcome email after registration', function () {
    Mail::fake();

    $this->postJson('/api/v1/auth/register', [
        'name' => 'John',
        'email' => 'john@example.com',
        'password' => 'password123',
        'password_confirmation' => 'password123',
    ]);

    Mail::assertSent(WelcomeEmail::class, function ($mail) {
        return $mail->hasTo('john@example.com');
    });
});

it('dispatches order processing job', function () {
    Queue::fake();

    $order = Order::factory()->create();

    $this->postJson("/api/v1/orders/{$order->id}/process");

    Queue::assertPushed(ProcessOrder::class, fn ($job) =>
        $job->order->id === $order->id
    );
});

it('fires event when order is placed', function () {
    Event::fake([OrderPlaced::class]);

    // ... create order

    Event::assertDispatched(OrderPlaced::class);
});

it('stores file upload', function () {
    Storage::fake('public');

    $file = UploadedFile::fake()->image('avatar.jpg', 200, 200);

    $this->postJson('/api/v1/me/avatar', ['avatar' => $file])
        ->assertOk();

    Storage::disk('public')->assertExists('avatars/' . $file->hashName());
});
```

### Time Travel

```php
it('expires orders after 30 days', function () {
    $order = Order::factory()->create(['status' => OrderStatus::Pending]);

    $this->travel(31)->days();

    $this->artisan('orders:expire-pending');

    expect($order->fresh()->status)->toBe(OrderStatus::Cancelled);
});
```

## Testing Rules

1. **Name tests descriptively** — `it('returns 404 when order not found')` not `it('test1')`
2. **One assertion concept per test** — test one behavior, not many
3. **Use `describe()` blocks** to group related tests
4. **Always test happy path AND error paths**
5. **Always test authorization** — ensure users can't access what they shouldn't
6. **Always test validation** — ensure invalid data is rejected
7. **Use factories** — never manually insert test data
8. **Use fakes** — Mail::fake(), Queue::fake(), Event::fake(), Storage::fake(), Notification::fake()
9. **Test database state** — `assertDatabaseHas()`, `assertDatabaseMissing()`, `assertSoftDeleted()`
10. **Use `LazilyRefreshDatabase`** instead of `RefreshDatabase` for speed (only refreshes when DB is touched)
11. **Run tests frequently** — `php artisan test --parallel` for speed

## What to Test

| Layer | What to Test |
|-------|-------------|
| **API endpoints** | Status codes, response structure, auth, validation, permissions |
| **Services** | Business logic correctness, edge cases, error handling |
| **Actions** | Input → output, exceptions |
| **Models** | Scopes, accessors, relationships, custom methods |
| **Jobs** | Side effects, retry logic, failure handling |
| **Mail/Notifications** | Content, recipients, queuing |
| **Commands** | Output, side effects, exit codes |
| **Policies** | All permission scenarios |

````
