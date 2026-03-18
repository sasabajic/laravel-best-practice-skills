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
