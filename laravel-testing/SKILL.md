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

## Architecture Testing with Pest

Pest's `arch()` function lets you enforce architectural rules as tests. Place architecture tests in `tests/Arch/` or `tests/ArchTest.php`.

### Strict Types and Code Quality

```php
<?php

arch('all files use strict types')
    ->expect('App')
    ->toUseStrictTypes();

arch('no debugging functions left in codebase')
    ->expect(['dd', 'dump', 'ray', 'var_dump', 'print_r'])
    ->not->toBeUsed();

arch('all classes are final by default')
    ->expect('App')
    ->toBeFinal();
```

### Inheritance and Extension Rules

```php
<?php

use App\Http\Controllers\Controller;
use Illuminate\Database\Eloquent\Model;

arch('models extend Eloquent Model')
    ->expect('App\Models')
    ->toExtend(Model::class);

arch('controllers extend base Controller')
    ->expect('App\Http\Controllers')
    ->toExtend(Controller::class);

arch('form requests extend FormRequest')
    ->expect('App\Http\Requests')
    ->toExtend('Illuminate\Foundation\Http\FormRequest');

arch('enums are string-backed')
    ->expect('App\Enums')
    ->toBeEnums()
    ->toHaveSuffix('Enum')
    ->toImplement(\BackedEnum::class);
```

### Namespace and Dependency Rules

```php
<?php

arch('models do not depend on controllers')
    ->expect('App\Models')
    ->not->toBeUsedIn('App\Http\Controllers');

arch('domain layer does not depend on infrastructure')
    ->expect('App\Domain')
    ->toOnlyBeUsedIn([
        'App\Services',
        'App\Actions',
        'App\Http\Controllers',
    ]);

arch('controllers only have expected dependencies')
    ->expect('App\Http\Controllers')
    ->toOnlyDependOn([
        'App\Http\Requests',
        'App\Services',
        'App\Actions',
        'App\Models',
        'App\Enums',
        'Illuminate',
    ]);

arch('actions are invokable')
    ->expect('App\Actions')
    ->toHaveMethod('__invoke');

arch('jobs implement ShouldQueue')
    ->expect('App\Jobs')
    ->toImplement('Illuminate\Contracts\Queue\ShouldQueue');
```

### Rules

- Place arch tests in a dedicated `tests/Arch/` directory or a single `tests/ArchTest.php` file.
- Enforce strict types across the entire `App` namespace.
- Always include a "no debugging functions" arch test.
- Enforce that models extend `Model`, controllers extend `Controller`, and form requests extend `FormRequest`.
- Use namespace dependency rules to prevent coupling between layers (e.g., models must not depend on controllers).
- Run arch tests in CI alongside feature and unit tests — they execute fast with zero I/O.
- See **laravel-code-style** skill for complementary static analysis and coding standard rules.

## Browser Testing with Laravel Dusk

Use Laravel Dusk for end-to-end browser testing when you need to verify JavaScript-driven UI, SPAs, or complex multi-step workflows that cannot be tested with HTTP tests.

### Installation and Setup

```bash
composer require laravel/dusk --dev
php artisan dusk:install
```

This creates `tests/Browser/`, a `DuskTestCase.php` base class, and a `chromedriver` binary.

### DuskTestCase Convention

```php
<?php

namespace Tests\Browser;

use Laravel\Dusk\TestCase as DuskTestCase;
use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;

abstract class DuskTestCase extends DuskTestCase
{
    protected function driver(): RemoteWebDriver
    {
        $options = (new ChromeOptions())->addArguments([
            '--disable-gpu',
            '--headless=new',
            '--window-size=1920,1080',
            '--no-sandbox',
        ]);

        return RemoteWebDriver::create(
            'http://localhost:9515',
            DesiredCapabilities::chrome()->setCapability(
                ChromeOptions::CAPABILITY,
                $options
            )
        );
    }
}
```

### Browser Interaction

```php
<?php

namespace Tests\Browser;

use App\Models\User;
use Laravel\Dusk\Browser;

test('user can submit the contact form', function () {
    $this->browse(function (Browser $browser) {
        $browser->visit('/contact')
            ->type('name', 'John Doe')
            ->type('email', 'john@example.com')
            ->type('message', 'Hello, I have a question.')
            ->press('Send Message')
            ->waitForText('Thank you for your message')
            ->assertSee('Thank you for your message');
    });
});

test('user can navigate through a multi-step wizard', function () {
    $this->browse(function (Browser $browser) {
        $browser->visit('/onboarding')
            ->waitFor('@step-1')
            ->type('@company-name', 'Acme Inc')
            ->press('Next')
            ->waitFor('@step-2')
            ->select('@plan', 'professional')
            ->press('Next')
            ->waitFor('@step-3')
            ->assertSee('Review your choices');
    });
});
```

### Authentication in Dusk

```php
<?php

use App\Models\User;
use Laravel\Dusk\Browser;

test('admin can access the dashboard', function () {
    $admin = User::factory()->admin()->create();

    $this->browse(function (Browser $browser) use ($admin) {
        $browser->loginAs($admin)
            ->visit('/admin/dashboard')
            ->assertSee('Admin Dashboard')
            ->assertPresent('@analytics-widget');
    });
});
```

### Screenshots on Failure

Dusk automatically captures screenshots when a test fails. Screenshots are stored in `tests/Browser/screenshots/`. You can also take manual screenshots:

```php
$browser->screenshot('checkout-step-3');
```

### Running in CI

```yaml
# .github/workflows/dusk.yml (excerpt)
- name: Start Chrome Driver
  run: ./vendor/laravel/dusk/bin/chromedriver-linux --port=9515 &

- name: Start Laravel Server
  run: php artisan serve --no-reload &

- name: Run Dusk Tests
  run: php artisan dusk --env=testing

- name: Upload Screenshots
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: dusk-screenshots
    path: tests/Browser/screenshots/
```

### When to Use Dusk vs HTTP Tests

| Scenario | Use |
|----------|-----|
| JSON API endpoint validation | HTTP tests (`getJson`, `postJson`) |
| Form submission without JS | HTTP tests |
| JavaScript-dependent UI | **Dusk** |
| Single-page application flows | **Dusk** |
| File uploads with JS preview | **Dusk** |
| Simple auth/redirect flows | HTTP tests |

### Rules

- Install Dusk as a `--dev` dependency only — never deploy it to production.
- Always run Dusk in `--headless` mode in CI.
- Use Dusk selectors (`dusk="selector"`) over CSS/XPath for resilient selectors — add `@` prefix in tests.
- Prefer HTTP feature tests over Dusk when JavaScript is not involved — they are faster and more reliable.
- Use `loginAs()` instead of typing credentials for authentication setup.
- Upload failure screenshots as CI artifacts for debugging.
- Keep Dusk tests in `tests/Browser/` separate from Feature and Unit tests.
- See **laravel-code-style** skill for Blade and frontend conventions tested by Dusk.

## Mutation Testing with Infection

Mutation testing verifies that your tests actually catch bugs. Infection modifies (mutates) your source code and checks whether your tests detect each change. Surviving mutants indicate weak or missing assertions.

### What Mutation Testing Catches

- Tests that pass but assert nothing meaningful.
- Boundary conditions not covered (e.g., `>` vs `>=`).
- Dead code that could be removed without test failures.
- Missing edge-case assertions in business logic.

### Installing and Configuring Infection

```bash
composer require infection/infection --dev
```

Create `infection.json5` in the project root:

```json5
{
    "$schema": "vendor/infection/infection/resources/schema.json",
    "source": {
        "directories": [
            "app/Services",
            "app/Actions",
            "app/Models"
        ]
    },
    "logs": {
        "text": "infection.log",
        "summary": "infection-summary.log"
    },
    "mutators": {
        "@default": true
    },
    "minMsi": 80,
    "minCoveredMsi": 90,
    "phpUnit": {
        "configDir": "."
    }
}
```

### Running Mutation Tests

```bash
# Run mutation tests (uses Pest/PHPUnit under the hood)
vendor/bin/infection --threads=4 --show-mutations

# Target specific directories
vendor/bin/infection --filter="App\\Services" --threads=4

# Only mutate lines covered by tests
vendor/bin/infection --only-covered --threads=4
```

### Interpreting MSI (Mutation Score Indicator)

| Metric | Meaning | Target |
|--------|---------|--------|
| **MSI** | % of mutants killed or causing errors | ≥ 80% |
| **Covered MSI** | MSI only for code covered by tests | ≥ 90% |
| **Covered Code MSI** | Mutation score for covered lines | ≥ 90% |

```
125 mutations were generated:
     105 mutants were killed
       5 mutants were not covered by tests
      10 mutants were caught by timeout
       5 escaped mutants

Metrics:
    Mutation Score Indicator (MSI): 92%
    Mutation Code Coverage: 96%
    Covered Code MSI: 95%
```

### Practical Workflow

```php
<?php

// Service with business logic to mutation-test
// app/Services/DiscountService.php
final class DiscountService
{
    public function calculate(Order $order): Money
    {
        if ($order->total->isGreaterThan(Money::of(100, 'USD'))) {
            return $order->total->multipliedBy('0.10');
        }

        if ($order->items->count() >= 5) {
            return $order->total->multipliedBy('0.05');
        }

        return Money::of(0, 'USD');
    }
}
```

```php
<?php

// Test that Infection validates
use App\Services\DiscountService;
use App\Models\Order;

describe('DiscountService', function () {
    it('applies 10% discount for orders over $100', function () {
        $order = Order::factory()->withTotal(150_00)->create();

        $discount = (new DiscountService())->calculate($order);

        expect($discount->getAmount()->toFloat())->toBe(15.0);
    });

    it('applies 5% discount for 5 or more items', function () {
        $order = Order::factory()
            ->withTotal(80_00)
            ->has(OrderItem::factory()->count(5))
            ->create();

        $discount = (new DiscountService())->calculate($order);

        expect($discount->getAmount()->toFloat())->toBe(4.0);
    });

    it('gives no discount for small orders with few items', function () {
        $order = Order::factory()
            ->withTotal(50_00)
            ->has(OrderItem::factory()->count(2))
            ->create();

        $discount = (new DiscountService())->calculate($order);

        expect($discount->getAmount()->toFloat())->toBe(0.0);
    });

    // Boundary test — Infection will mutate > to >= and vice versa
    it('does not apply 10% discount for exactly $100', function () {
        $order = Order::factory()->withTotal(100_00)->create();

        $discount = (new DiscountService())->calculate($order);

        expect($discount->getAmount()->toFloat())->toBe(0.0);
    });
});
```

### Rules

- Run Infection against `app/Services`, `app/Actions`, and `app/Models` — focus on business logic, not framework boilerplate.
- Set a minimum MSI threshold (≥ 80%) and enforce it in CI with `--min-msi=80`.
- Use `--only-covered` to avoid noise from untested code during initial adoption.
- Fix surviving mutants by adding missing boundary and edge-case assertions.
- Run mutation tests in a separate CI step (they are slower than standard tests).
- Combine Infection with code coverage to find both uncovered and weakly tested code.
- See **laravel-code-style** skill for ensuring the tested code follows consistent patterns.

## Test Performance

Keep test suites fast so developers run them frequently. Slow tests erode test discipline.

### Use LazilyRefreshDatabase over RefreshDatabase

```php
<?php

// tests/Pest.php
use Tests\TestCase;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;

pest()->extend(TestCase::class)
    ->use(LazilyRefreshDatabase::class)
    ->in('Feature');
```

`LazilyRefreshDatabase` only triggers a migration when a test actually touches the database. Tests that don't use the database skip migration entirely, saving significant time.

### Parallel Testing

```bash
# Run tests in parallel across CPU cores
php artisan test --parallel

# Specify the number of processes
php artisan test --parallel --processes=8

# Parallel with coverage
php artisan test --parallel --coverage --min=80
```

```php
<?php

// tests/Pest.php — parallel-safe configuration
use Illuminate\Support\Facades\ParallelTesting;

ParallelTesting::setUpProcess(function (int $token) {
    // Runs once per process — seed shared fixtures
});

ParallelTesting::setUpTestCase(function (int $token, TestCase $testCase) {
    // Runs before each test case in each process
});
```

### In-Memory SQLite for Unit Tests

```xml
<!-- phpunit.xml — use SQLite in-memory for speed -->
<php>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>
</php>
```

> **Note:** SQLite has behavioral differences from MySQL/PostgreSQL (e.g., no `JSON` column type, different string collation). Use it for unit tests but prefer the real database driver for feature tests.

### Avoiding Unnecessary I/O

```php
<?php

use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;

// Fake external services to eliminate I/O
beforeEach(function () {
    Storage::fake('s3');
    Http::fake();
    Mail::fake();
});

// Avoid file system writes in assertions
it('generates a report', function () {
    $service = new ReportService();

    $content = $service->generate(period: 'monthly');

    // Assert the return value, not a file on disk
    expect($content)
        ->toBeString()
        ->toContain('Monthly Report');
});
```

### Test Grouping and Filtering

```php
<?php

// Group slow tests so they can be excluded during local development
it('processes a large batch of orders', function () {
    // ...
})->group('slow');

it('sends weekly digest to all users', function () {
    // ...
})->group('slow', 'mail');
```

```bash
# Run only fast tests during development
php artisan test --exclude-group=slow

# Run only specific groups in CI
php artisan test --group=api

# Run a single test file
php artisan test --filter=OrderServiceTest
```

### Rules

- Use `LazilyRefreshDatabase` instead of `RefreshDatabase` in `tests/Pest.php` — it is the default for new projects.
- Run `php artisan test --parallel` in CI to reduce total test time.
- Fake all external services (`Http::fake()`, `Mail::fake()`, `Storage::fake()`) — never hit real APIs or file systems in tests.
- Group slow tests with `->group('slow')` and exclude them during rapid local iteration.
- Use in-memory SQLite for true unit tests, but use the production database driver for feature tests to catch driver-specific issues.
- Set a coverage threshold (`--min=80`) and enforce it in CI.
- Profile slow tests periodically with `--log-junit` and address tests taking over 1 second.
- See **laravel-code-style** skill for test naming conventions and file organization standards.
