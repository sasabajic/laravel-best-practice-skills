---
name: laravel-architecture
description: Laravel architectural patterns and design principles including Service classes, Action classes, DTOs, Repository pattern, SOLID principles, event-driven architecture, and domain-driven design within Laravel applications.
---

# Laravel Architecture & Design Patterns

Follow these architectural patterns and design principles when building Laravel applications.

## Service Layer Pattern

Use **Service classes** to encapsulate business logic that involves multiple models, external APIs, or complex operations. Controllers delegate to services.

### When to Use Services

- Logic that involves multiple models or database operations
- Business rules and workflows
- Integration with external APIs or third-party services
- Logic that is reused across multiple controllers or commands
- Complex operations that would make controllers fat

### Service Class Convention

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\DTOs\CreateUserData;
use App\Models\User;
use Illuminate\Support\Facades\DB;

final class UserService
{
    public function __construct(
        private readonly NotificationService $notificationService,
    ) {}

    public function create(CreateUserData $data): User
    {
        return DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data->name,
                'email' => $data->email,
                'password' => bcrypt($data->password),
            ]);

            $user->profile()->create($data->profileData());

            $this->notificationService->sendWelcome($user);

            return $user;
        });
    }

    public function update(User $user, UpdateUserData $data): User
    {
        $user->update($data->toArray());

        return $user->fresh();
    }
}
```

### Service Rules

- Mark service classes as `final` unless inheritance is explicitly needed
- Inject dependencies via constructor
- Use `readonly` for injected dependencies
- Use **DTOs** as parameters instead of raw arrays
- Wrap multi-step operations in `DB::transaction()`
- One service per domain entity (e.g., `UserService`, `OrderService`)
- Services can call other services
- Never inject `Request` into services — pass DTOs or simple values

## Action Classes

Use **Action classes** for single-purpose operations. An action does ONE thing.

### When to Use Actions

- The operation is a single, well-defined task
- The same operation is needed from multiple entry points (controller, command, job)
- You want maximum reusability and testability

### Action Convention

```php
<?php

declare(strict_types=1);

namespace App\Actions;

use App\DTOs\CreateInvoiceData;
use App\Models\Invoice;
use App\Models\Order;

final class CreateInvoiceFromOrder
{
    public function __construct(
        private readonly InvoiceNumberGenerator $generator,
        private readonly TaxCalculator $taxCalculator,
    ) {}

    public function execute(Order $order): Invoice
    {
        $tax = $this->taxCalculator->calculate($order->total, $order->taxRate);

        return Invoice::create([
            'order_id' => $order->id,
            'number' => $this->generator->next(),
            'subtotal' => $order->total,
            'tax' => $tax,
            'total' => $order->total + $tax,
        ]);
    }
}
```

### Action Rules

- One public method: `execute()` (or `__invoke()` if used as callable)
- Action name should be a verb phrase: `CreateUser`, `SendInvoice`, `CalculateDiscount`
- Mark as `final`
- Actions can call other actions
- Actions can be dispatched as jobs if they implement `ShouldQueue`

## Data Transfer Objects (DTOs)

Use **DTOs** to pass structured data between layers. Never pass raw arrays for complex data.

```php
<?php

declare(strict_types=1);

namespace App\DTOs;

final readonly class CreateUserData
{
    public function __construct(
        public string $name,
        public string $email,
        public string $password,
        public ?string $phone = null,
        public ?string $avatar = null,
    ) {}

    public static function fromRequest(StoreUserRequest $request): self
    {
        return new self(
            name: $request->validated('name'),
            email: $request->validated('email'),
            password: $request->validated('password'),
            phone: $request->validated('phone'),
            avatar: $request->validated('avatar'),
        );
    }

    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
            email: $data['email'],
            password: $data['password'],
            phone: $data['phone'] ?? null,
            avatar: $data['avatar'] ?? null,
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'name' => $this->name,
            'email' => $this->email,
            'password' => $this->password,
            'phone' => $this->phone,
            'avatar' => $this->avatar,
        ], fn ($value) => $value !== null);
    }
}
```

### DTO Rules

- Use `readonly` class modifier (PHP 8.2+)
- Use constructor promotion for all properties
- Provide `fromRequest()` and/or `fromArray()` factory methods
- Provide `toArray()` when needed for persistence
- DTOs are **immutable** — never add setters
- Use nullable types with defaults for optional fields

## Repository Pattern

Use the Repository pattern **only when you need to abstract data access** (e.g., when you might switch data sources, or for complex query logic that doesn't belong in the model).

### When to Use Repository

- Complex queries that are reused across multiple services
- When you want to centralize query logic
- When testing requires mocking data access
- NOT for simple CRUD — Eloquent is already a repository

### Repository Convention

```php
<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface UserRepositoryInterface
{
    public function findById(int $id): ?User;
    public function getActiveUsers(): Collection;
    public function searchByName(string $query, int $perPage = 15): LengthAwarePaginator;
}

final class UserRepository implements UserRepositoryInterface
{
    public function findById(int $id): ?User
    {
        return User::find($id);
    }

    public function getActiveUsers(): Collection
    {
        return User::query()
            ->where('is_active', true)
            ->orderByDesc('last_login_at')
            ->get();
    }

    public function searchByName(string $query, int $perPage = 15): LengthAwarePaginator
    {
        return User::query()
            ->where('name', 'like', "%{$query}%")
            ->paginate($perPage);
    }
}
```

Bind in `AppServiceProvider`:
```php
$this->app->bind(UserRepositoryInterface::class, UserRepository::class);
```

## Event-Driven Architecture

Use **Events and Listeners** to decouple side effects from core business logic.

### When to Use Events

- Sending notifications after an action
- Logging or auditing
- Syncing with external systems
- Any side effect that shouldn't block the main operation
- When multiple things need to happen in response to one action

### Event Convention

```php
// Event
final class OrderPlaced
{
    public function __construct(
        public readonly Order $order,
    ) {}
}

// Listener
final class SendOrderConfirmation implements ShouldQueue
{
    public function handle(OrderPlaced $event): void
    {
        $event->order->user->notify(new OrderConfirmationNotification($event->order));
    }
}

// Dispatching
OrderPlaced::dispatch($order);
// or
event(new OrderPlaced($order));
```

### Event Rules

- Event classes are simple data containers — no logic
- Listeners do the work
- Use `ShouldQueue` on listeners for non-blocking side effects
- Name events in **past tense**: `OrderPlaced`, `UserRegistered`, `PaymentFailed`
- Name listeners as **actions**: `SendOrderConfirmation`, `UpdateInventory`

## SOLID Principles in Laravel

### Single Responsibility (S)
- One class = one reason to change
- Controllers handle HTTP, Services handle business logic, Repositories handle data access

### Open/Closed (O)
- Use interfaces and contracts
- Strategy pattern via Laravel's service container

### Liskov Substitution (L)
- Implementations must be interchangeable via their interfaces
- Bind interfaces in service providers

### Interface Segregation (I)
- Prefer many small, focused interfaces over large ones
- Use Laravel's built-in contracts as examples

### Dependency Inversion (D)
- Depend on abstractions (interfaces), not concrete implementations
- Use constructor injection
- Bind implementations in service providers

## Architecture Decision Flow

When deciding where to put code, follow this decision tree:

1. **Is it validation?** → Form Request
2. **Is it response transformation?** → API Resource
3. **Is it a database query?** → Model scope or Repository
4. **Is it a single-purpose operation?** → Action class
5. **Is it multi-step business logic?** → Service class
6. **Is it a side effect of an action?** → Event + Listener
7. **Is it a model behavior/attribute?** → Model method, accessor, or cast
8. **Is it a scheduled/background task?** → Job (queued)
9. **Is it reusable logic across models?** → Trait
10. **Is it a fixed set of values?** → Enum

## Pipeline Pattern

Use Laravel's **Pipeline** to process data through a sequence of stages. Each stage (pipe) performs one transformation and passes the result to the next.

### When to Use Pipeline vs Service

- Use a **Pipeline** when data flows through multiple independent, sequential steps that can be reordered or toggled
- Use a **Service** when steps are tightly coupled or have complex branching logic
- Pipelines are ideal for: filtering queries, processing orders, transforming input, middleware-like chains

### Pipeline Class Example

```php
<?php

declare(strict_types=1);

namespace App\Pipelines\Order;

use App\DTOs\OrderContext;
use Illuminate\Support\Facades\Pipeline;

final class ProcessOrderPipeline
{
    /**
     * @param list<class-string> $pipes
     */
    public function __construct(
        private readonly array $pipes = [
            ValidateInventory::class,
            CalculatePricing::class,
            ApplyDiscount::class,
            CalculateTax::class,
            FinalizeOrder::class,
        ],
    ) {}

    public function handle(OrderContext $context): OrderContext
    {
        return Pipeline::send($context)
            ->through($this->pipes)
            ->thenReturn();
    }
}
```

### Individual Pipe Example

```php
<?php

declare(strict_types=1);

namespace App\Pipelines\Order;

use App\DTOs\OrderContext;
use App\Exceptions\InsufficientInventoryException;
use Closure;

final class ValidateInventory
{
    public function handle(OrderContext $context, Closure $next): mixed
    {
        foreach ($context->items as $item) {
            if ($item->product->stock < $item->quantity) {
                throw new InsufficientInventoryException($item->product);
            }
        }

        return $next($context);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Pipelines\Order;

use App\DTOs\OrderContext;
use App\Services\TaxCalculator;
use Closure;

final class CalculateTax
{
    public function __construct(
        private readonly TaxCalculator $taxCalculator,
    ) {}

    public function handle(OrderContext $context, Closure $next): mixed
    {
        $context->tax = $this->taxCalculator->calculate(
            subtotal: $context->subtotal,
            region: $context->shippingAddress->region,
        );

        $context->total = $context->subtotal + $context->tax;

        return $next($context);
    }
}
```

### Pipeline Context DTO

```php
<?php

declare(strict_types=1);

namespace App\DTOs;

use App\Models\User;
use Illuminate\Support\Collection;

final class OrderContext
{
    public int $subtotal = 0;
    public int $tax = 0;
    public int $discount = 0;
    public int $total = 0;

    public function __construct(
        public readonly User $user,
        public readonly Collection $items,
        public readonly AddressData $shippingAddress,
    ) {}
}
```

### Pipeline Rules

- Each pipe has a single `handle(mixed $passable, Closure $next): mixed` method
- Pipes must call `$next($passable)` to continue the chain (or throw to abort)
- Keep pipes small — one responsibility per pipe
- Inject dependencies via constructor in each pipe
- Use a context DTO to carry state through the pipeline
- Mark pipe classes as `final`
- Name pipes as verb phrases: `ValidateInventory`, `ApplyDiscount`, `CalculateTax`

## Value Objects

**Value Objects** represent domain concepts defined by their attributes, not by identity. Unlike DTOs (which are data carriers), Value Objects contain behavior and enforce invariants.

### What Makes a Value Object

- **Immutable** — once created, cannot be changed
- **Equality by value** — two objects with the same attributes are equal
- **Self-validating** — rejects invalid state at construction
- **Contains behavior** — methods that operate on the value

### Examples

```php
<?php

declare(strict_types=1);

namespace App\ValueObjects;

use InvalidArgumentException;

final readonly class Money
{
    public function __construct(
        public int $amount,
        public string $currency,
    ) {
        if ($amount < 0) {
            throw new InvalidArgumentException('Amount cannot be negative.');
        }

        if (strlen($currency) !== 3) {
            throw new InvalidArgumentException('Currency must be a 3-letter ISO code.');
        }
    }

    public function add(self $other): self
    {
        $this->ensureSameCurrency($other);

        return new self($this->amount + $other->amount, $this->currency);
    }

    public function subtract(self $other): self
    {
        $this->ensureSameCurrency($other);

        return new self($this->amount - $other->amount, $this->currency);
    }

    public function multiply(int $factor): self
    {
        return new self($this->amount * $factor, $this->currency);
    }

    public function equals(self $other): bool
    {
        return $this->amount === $other->amount
            && $this->currency === $other->currency;
    }

    public function formatCents(): string
    {
        return number_format($this->amount / 100, 2) . ' ' . $this->currency;
    }

    private function ensureSameCurrency(self $other): void
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException('Cannot operate on different currencies.');
        }
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\ValueObjects;

use InvalidArgumentException;

final readonly class Email
{
    public readonly string $value;

    public function __construct(string $value)
    {
        $normalized = mb_strtolower(trim($value));

        if (! filter_var($normalized, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException("Invalid email address: {$value}");
        }

        $this->value = $normalized;
    }

    public function domain(): string
    {
        return substr($this->value, strpos($this->value, '@') + 1);
    }

    public function equals(self $other): bool
    {
        return $this->value === $other->value;
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\ValueObjects;

use Carbon\CarbonImmutable;
use InvalidArgumentException;

final readonly class DateRange
{
    public function __construct(
        public CarbonImmutable $start,
        public CarbonImmutable $end,
    ) {
        if ($start->isAfter($end)) {
            throw new InvalidArgumentException('Start date must be before end date.');
        }
    }

    public function overlaps(self $other): bool
    {
        return $this->start->isBefore($other->end)
            && $this->end->isAfter($other->start);
    }

    public function contains(CarbonImmutable $date): bool
    {
        return $date->isBetween($this->start, $this->end);
    }

    public function lengthInDays(): int
    {
        return $this->start->diffInDays($this->end);
    }

    public function equals(self $other): bool
    {
        return $this->start->equalTo($other->start)
            && $this->end->equalTo($other->end);
    }
}
```

### When to Use Value Objects vs DTOs vs Enums

| Use | When |
|-----|------|
| **Value Object** | The concept has behavior, invariants, or is used in comparisons (Money, Email, DateRange) |
| **DTO** | You need to transfer a group of fields between layers without behavior (CreateUserData) |
| **Enum** | The value is one of a fixed, finite set (OrderStatus, Role, Currency) |

### Value Object Rules

- Always `final readonly class`
- Validate in the constructor — reject invalid state immediately
- Return new instances from transformation methods (immutability)
- Implement `equals()` for value comparison
- Use in Eloquent via custom casts when persisting to the database
- Do NOT add setters or mutable state

## Domain-Driven Design (DDD) Structure

For large applications, organize code by **domain** instead of by technical layer. Each domain contains its own models, services, actions, and events.

### Folder Structure

```
app/
├── Domains/
│   ├── Order/
│   │   ├── Actions/
│   │   │   └── PlaceOrder.php
│   │   ├── DTOs/
│   │   │   └── CreateOrderData.php
│   │   ├── Events/
│   │   │   └── OrderPlaced.php
│   │   ├── Exceptions/
│   │   │   └── OrderLimitExceededException.php
│   │   ├── Listeners/
│   │   │   └── SendOrderConfirmation.php
│   │   ├── Models/
│   │   │   ├── Order.php
│   │   │   └── OrderItem.php
│   │   ├── Pipelines/
│   │   │   ├── ProcessOrderPipeline.php
│   │   │   └── Pipes/
│   │   ├── Policies/
│   │   │   └── OrderPolicy.php
│   │   ├── Services/
│   │   │   └── OrderService.php
│   │   └── ValueObjects/
│   │       └── OrderTotal.php
│   ├── User/
│   │   ├── Actions/
│   │   ├── DTOs/
│   │   ├── Events/
│   │   ├── Models/
│   │   │   └── User.php
│   │   ├── Services/
│   │   │   └── UserService.php
│   │   └── ValueObjects/
│   │       └── Email.php
│   └── Payment/
│       ├── Actions/
│       ├── DTOs/
│       ├── Models/
│       ├── Services/
│       │   └── PaymentGatewayService.php
│       └── ValueObjects/
│           └── Money.php
├── Http/
│   ├── Controllers/
│   │   ├── OrderController.php
│   │   └── UserController.php
│   ├── Requests/
│   └── Resources/
└── Providers/
```

### What Goes in Each Domain Folder

| Folder | Contains |
|--------|----------|
| `Models/` | Eloquent models belonging to this domain |
| `Services/` | Business logic coordinating domain operations |
| `Actions/` | Single-purpose operations within this domain |
| `DTOs/` | Data transfer objects for this domain |
| `Events/` | Domain events (past-tense named) |
| `Listeners/` | Event handlers for this domain's events |
| `Pipelines/` | Pipeline classes and pipes |
| `ValueObjects/` | Immutable value types for this domain |
| `Exceptions/` | Domain-specific exception classes |
| `Policies/` | Authorization policies for domain models |

### When to Use DDD vs Standard Laravel Structure

- **Standard structure** — small to medium apps, fewer than ~15 models, small team
- **DDD structure** — large apps, many bounded contexts, multiple teams working on separate domains
- You can adopt DDD incrementally — start standard and extract domains as complexity grows

### DDD Rules

- A domain **never** directly accesses another domain's models — use services or events to communicate
- Controllers and routes stay in `app/Http/` — they are the infrastructure layer, not the domain
- Keep the domain layer framework-agnostic where possible
- Each domain should have its own service provider if it needs bindings
- Anti-pattern: creating a domain for every model — group by business capability, not by table

## Anti-Patterns — What NOT to Do

Avoid these common architecture mistakes in Laravel applications.

### Fat Controllers

**Problem:** Controllers containing business logic, validation, database queries, and side effects all in one method.

```php
// ❌ Bad — controller does everything
final class OrderController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([/* ... */]);
        $order = Order::create($validated);
        $order->items()->createMany($request->input('items'));
        $total = $order->items->sum(fn ($item) => $item->price * $item->quantity);
        $order->update(['total' => $total]);
        Mail::to($order->user)->send(new OrderConfirmation($order));

        return response()->json($order);
    }
}
```

**Fix:** Move validation to a Form Request, business logic to a Service or Action, and side effects to Events.

### Anemic Domain Models

**Problem:** Models that are nothing but column definitions — all behavior lives in services.

**Fix:** Put behavior that belongs to the model on the model. Scopes, accessors, relationships, and simple state checks belong on the Eloquent model. Services coordinate multi-model operations.

### God Services

**Problem:** A single service class that handles everything for a domain — hundreds of methods, thousands of lines.

**Fix:** Split into focused services or extract Action classes. Each class should have a single responsibility.

### Over-Engineering

**Problem:** Using Repository pattern for simple CRUD, creating a DTO for a single field, wrapping every Eloquent call in an abstraction.

```php
// ❌ Bad — unnecessary abstraction
final class UserRepository
{
    public function findById(int $id): ?User
    {
        return User::find($id); // Eloquent already does this
    }
}
```

**Fix:** Use patterns only when they provide clear value. Eloquent IS your data access layer for simple operations. Introduce abstractions when complexity demands it.

### Circular Service Dependencies

**Problem:** `OrderService` depends on `PaymentService`, which depends on `OrderService`.

**Fix:** Extract shared logic into a third service, use events to decouple, or restructure the dependency graph. If two services always need each other, they may belong together.

### Business Logic in Blade Views

**Problem:** Calculating prices, checking permissions with raw logic, or querying the database in Blade templates.

```php
// ❌ Bad — logic in Blade
@if ($user->orders()->where('status', 'active')->where('total', '>', 1000)->exists())
    <span>VIP Customer</span>
@endif
```

**Fix:** Use model accessors, computed properties, or View Models.

```php
// ✅ Good — logic on the model
// In User model:
public function isVip(): bool
{
    return $this->orders()
        ->where('status', 'active')
        ->where('total', '>', 1000)
        ->exists();
}

// In Blade:
@if ($user->isVip())
    <span>VIP Customer</span>
@endif
```

### Business Logic in Migrations

**Problem:** Running data transformations, sending emails, or calling APIs inside migration files.

**Fix:** Migrations should only modify database schema. Use seeders, commands, or one-time jobs for data operations.

> See also: **laravel-eloquent-database** skill for model conventions.
