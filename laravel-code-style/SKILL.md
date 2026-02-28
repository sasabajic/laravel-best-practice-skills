````skill
---
name: laravel-code-style
description: Laravel code style and quality standards including PSR-12, Laravel Pint configuration, PHPStan/Larastan static analysis, naming conventions, code formatting, import ordering, and consistent coding patterns.
---

# Laravel Code Style & Quality

Follow these code style and quality standards in all Laravel code.

## Laravel Pint (Code Formatter)

Use **Laravel Pint** as the code formatter. Configure in `pint.json`:

```json
{
    "preset": "laravel",
    "rules": {
        "declare_strict_types": true,
        "final_class": true,
        "void_return": true,
        "ordered_imports": {
            "sort_algorithm": "alpha",
            "imports_order": ["const", "class", "function"]
        },
        "single_trait_insert_per_statement": true,
        "trailing_comma_in_multiline": {
            "elements": ["arguments", "arrays", "match", "parameters"]
        },
        "native_function_invocation": {
            "include": ["@all"]
        },
        "global_namespace_import": {
            "import_classes": true,
            "import_constants": false,
            "import_functions": false
        },
        "no_unused_imports": true,
        "blank_line_before_statement": {
            "statements": ["return", "throw", "try"]
        }
    }
}
```

Run Pint: `./vendor/bin/pint`

## PHPStan / Larastan (Static Analysis)

Use **Larastan** for static analysis. Configure in `phpstan.neon`:

```neon
includes:
    - vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - app/
    level: 8
    checkMissingIterableValueType: false
    checkGenericClassInNonGenericObjectType: false
```

Run: `./vendor/bin/phpstan analyse`

**Target: Level 8** (maximum strictness). Start at level 5 and gradually increase.

## Naming Conventions (Detailed)

### Classes

```php
// Controllers — singular resource + Controller
class UserController {}
class OrderItemController {}
class Api\V1\ProductController {}        // API versioned
class CancelOrderController {}           // Single-action

// Models — singular, PascalCase
class User {}
class OrderItem {}
class BlogPost {}

// Services — PascalCase + Service
class PaymentService {}
class UserNotificationService {}

// Actions — verb + noun
class CreateUser {}
class CalculateOrderTotal {}
class SendInvoiceEmail {}

// DTOs — noun + Data
class CreateUserData {}
class OrderFilterData {}

// Events — past tense
class OrderPlaced {}
class UserRegistered {}
class PaymentFailed {}

// Listeners — descriptive action
class SendOrderConfirmation {}
class UpdateUserStatistics {}

// Jobs — descriptive action
class ProcessPayment {}
class GenerateMonthlyReport {}

// Form Requests — verb + model + Request
class StoreUserRequest {}
class UpdateOrderRequest {}
class FilterProductRequest {}

// Resources — model + Resource
class UserResource {}
class OrderCollection {}

// Enums — singular noun
enum UserRole: string {}
enum OrderStatus: string {}
enum PaymentMethod: string {}
```

### Methods and Functions

```php
// Getters — get, find, fetch
public function getActiveUsers(): Collection {}
public function findByEmail(string $email): ?User {}
public function fetchLatestOrders(): Collection {}

// Setters / Actions — verb
public function assignRole(Role $role): void {}
public function markAsShipped(): void {}
public function calculateTotal(): float {}

// Boolean methods — is, has, can, should
public function isActive(): bool {}
public function hasPermission(string $permission): bool {}
public function canBeCancelled(): bool {}
public function shouldNotify(): bool {}

// Scopes — adjective or noun phrase
public function scopeActive(Builder $query): Builder {}
public function scopeForUser(Builder $query, User $user): Builder {}
public function scopeCreatedAfter(Builder $query, Carbon $date): Builder {}

// Accessors — the attribute name (Laravel 11 attribute cast)
protected function fullName(): Attribute {}
protected function formattedPrice(): Attribute {}
```

### Variables

```php
// Collections — plural
$users = User::all();
$activeOrders = Order::active()->get();

// Single models — singular
$user = User::find($id);
$latestOrder = $user->orders()->latest()->first();

// Booleans — is/has/can prefix or past tense
$isActive = true;
$hasPermission = $user->can('edit');
$canDelete = $policy->delete($user, $order);
$isVerified = $user->hasVerifiedEmail();

// Counts — suffix Count or Total
$orderCount = Order::count();
$userTotal = User::where('active', true)->count();

// Temporary / computed
$discount = $this->calculateDiscount($order);
$taxAmount = $subtotal * $taxRate;
```

### Database

```php
// Tables — plural, snake_case
// users, order_items, blog_posts, category_product (pivot)

// Columns — singular, snake_case
// first_name, is_active, created_at, user_id

// Foreign keys — singular model + _id
// user_id, order_id, category_id

// Pivot tables — singular models alphabetical + snake_case
// category_product, role_user

// Indexes — table_column_type
// orders_status_index, users_email_unique
```

## Import Ordering

Organize imports in this order:

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

// 1. PHP built-in classes
use InvalidArgumentException;
use RuntimeException;

// 2. Framework / vendor classes (alphabetical)
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

// 3. Application classes (alphabetical)
use App\DTOs\CreateUserData;
use App\Http\Requests\StoreUserRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\UserService;
```

## Code Formatting Rules

### Brackets and Spacing

```php
// Method chaining — one call per line when chaining 3+
$users = User::query()
    ->where('is_active', true)
    ->whereHas('orders')
    ->orderByDesc('created_at')
    ->paginate(15);

// Short closures when single expression
$names = $users->map(fn (User $user) => $user->name);

// Multi-line closures for complex logic
$users->each(function (User $user) {
    $user->notify(new WelcomeNotification());
    $user->update(['notified_at' => now()]);
});

// Ternary — only for simple conditions
$status = $order->isPaid() ? 'active' : 'pending';

// Match expressions — preferred over switch
$label = match ($status) {
    OrderStatus::Pending => 'Pending Review',
    OrderStatus::Active => 'Active',
    OrderStatus::Shipped => 'Shipped',
    default => 'Unknown',
};
```

### Trailing Commas

Always use trailing commas in multi-line:

```php
// Arrays
$config = [
    'driver' => 'redis',
    'connection' => 'default',
    'queue' => 'emails',
]; // ← trailing comma

// Function parameters
public function create(
    string $name,
    string $email,
    ?string $phone = null,
): User { // ← trailing comma
    // ...
}

// Function calls
$this->service->process(
    order: $order,
    notify: true,
    priority: 'high',
); // ← trailing comma

// Match
$result = match ($type) {
    'a' => 'Alpha',
    'b' => 'Beta',
}; // ← trailing comma
```

## Code Quality Checklist

When writing or reviewing Laravel code, verify:

- [ ] `declare(strict_types=1)` at top of every file
- [ ] All parameters, return types, and properties are typed
- [ ] Classes are `final` unless inheritance is needed
- [ ] No unused imports
- [ ] Imports are alphabetically ordered
- [ ] No `dd()`, `dump()`, `ray()` left in code
- [ ] No `env()` calls outside config files
- [ ] Validation is in Form Requests, not controllers
- [ ] No mass assignment with `$request->all()`
- [ ] Relationships have return types
- [ ] Consistent naming conventions followed
- [ ] No magic strings — use Enums or constants
- [ ] Trailing commas in multi-line structures
- [ ] No deeply nested code (max 2-3 levels) — extract methods
- [ ] No long methods (max ~20 lines) — extract into smaller methods

````
