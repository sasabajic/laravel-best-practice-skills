````skill
---
name: laravel-security
description: Laravel security best practices including validation, Form Requests, authorization with Policies and Gates, CSRF protection, XSS prevention, SQL injection prevention, rate limiting, input sanitization, and security hardening techniques.
---

# Laravel Security Best Practices

Follow these security practices in all Laravel applications. Security must be built into every layer.

## Form Requests — ALWAYS Validate Input

**Never validate in controllers.** Always use dedicated Form Request classes.

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Enums\OrderStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Enum;
use Illuminate\Validation\Rules\Password;

final class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Use Policies for complex auth logic
        return $this->user()->can('create', Order::class);
    }

    public function rules(): array
    {
        return [
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:100'],
            'shipping_address_id' => ['required', 'exists:addresses,id'],
            'notes' => ['nullable', 'string', 'max:500'],
            'coupon_code' => ['nullable', 'string', 'exists:coupons,code'],
        ];
    }

    public function messages(): array
    {
        return [
            'items.required' => 'At least one item is required.',
            'items.*.product_id.exists' => 'One or more selected products do not exist.',
        ];
    }

    // Sanitize/prepare data before validation
    protected function prepareForValidation(): void
    {
        $this->merge([
            'notes' => $this->notes ? strip_tags($this->notes) : null,
        ]);
    }
}
```

### Validation Rules — Examples

```php
// User registration
public function rules(): array
{
    return [
        'name' => ['required', 'string', 'min:2', 'max:255'],
        'email' => ['required', 'email:rfc,dns', Rule::unique('users')],
        'password' => ['required', 'confirmed', Password::min(8)->mixedCase()->numbers()->symbols()],
        'phone' => ['nullable', 'string', 'regex:/^\+?[1-9]\d{1,14}$/'],
        'avatar' => ['nullable', 'image', 'mimes:jpg,png,webp', 'max:2048', 'dimensions:max_width=2000,max_height=2000'],
        'role' => ['required', new Enum(UserRole::class)],
    ];
}

// User update (unique except self)
public function rules(): array
{
    return [
        'email' => ['required', 'email', Rule::unique('users')->ignore($this->user())],
        'name' => ['required', 'string', 'max:255'],
    ];
}
```

### Form Request Rules

- **Always return typed `rules()` array** — use array syntax, not pipe-delimited strings
- Use `Rule::` builders for complex rules (`unique`, `exists`, `in`, `requiredIf`)
- Use `Password::defaults()` configured in `AppServiceProvider` for consistent password rules
- Use `prepareForValidation()` for data sanitization
- Use `$this->validated()` to get only validated data — NEVER use `$request->all()`
- Use `$this->safe()->only([...])` when you need a subset

## Authorization — Policies

Use **Policies** for model-based authorization. Use **Gates** for non-model authorization.

### Policy Convention

```php
<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Order;
use App\Models\User;

final class OrderPolicy
{
    // Before all checks — admin bypass
    public function before(User $user, string $ability): ?bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        return null; // Fall through to specific check
    }

    public function viewAny(User $user): bool
    {
        return true; // All authenticated users can list
    }

    public function view(User $user, Order $order): bool
    {
        return $user->id === $order->user_id;
    }

    public function create(User $user): bool
    {
        return $user->hasVerifiedEmail();
    }

    public function update(User $user, Order $order): bool
    {
        return $user->id === $order->user_id && $order->isPending();
    }

    public function delete(User $user, Order $order): bool
    {
        return $user->id === $order->user_id && $order->canBeCancelled();
    }
}
```

### Using Authorization

```php
// In controllers — authorize in Form Request or controller
public function update(UpdateOrderRequest $request, Order $order): OrderResource
{
    $this->authorize('update', $order);
    // or Gate::authorize('update', $order);

    // ...
}

// In Blade
@can('update', $order)
    <button>Edit Order</button>
@endcan

// In middleware
Route::put('orders/{order}', [OrderController::class, 'update'])
    ->can('update', 'order');
```

### Authorization Rules

- **One Policy per Model** — auto-discovered by convention
- Use `before()` sparingly — only for admin bypass
- Return `bool` — true = allowed, false = denied
- Return `null` in `before()` to fall through to specific method
- Register policies auto-discovery or in `AuthServiceProvider`
- Use `$this->authorize()` in controllers
- Use `@can` / `@cannot` in Blade views
- Use `->can()` middleware on routes

## SQL Injection Prevention

```php
// GOOD — Eloquent and query builder use prepared statements automatically
User::where('email', $email)->first();

// GOOD — parameter binding
DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// BAD — raw string interpolation = SQL injection vulnerability
DB::select("SELECT * FROM users WHERE email = '$email'"); // NEVER DO THIS

// SAFE raw expressions when needed
User::whereRaw('LOWER(name) = ?', [strtolower($name)])->get();
```

### Rules

- **NEVER concatenate user input into raw queries**
- Always use Eloquent or Query Builder (parameterized by default)
- When using `DB::raw()`, `whereRaw()`, `selectRaw()` — always use `?` parameter binding
- Use `DB::select()` with bindings array for complex raw queries

## XSS Prevention

```php
// Blade automatically escapes output
{{ $user->name }}           // Escaped — SAFE
{!! $user->bio !!}          // Unescaped — DANGEROUS, use only for trusted HTML

// NEVER use {!! !!} with user input
// If you need HTML, sanitize first:
{!! clean($user->bio) !!}  // Using a sanitization library
```

### Rules

- Always use `{{ }}` (double curly braces) — auto-escaped
- Never use `{!! !!}` with user input
- Sanitize HTML input before storage using packages like `mews/purifier`
- Set Content Security Policy headers
- Use `@js()` directive for passing data to JavaScript safely

## CSRF Protection

- All POST/PUT/PATCH/DELETE forms must include `@csrf`
- API routes (Sanctum token auth) are exempted from CSRF
- SPA with Sanctum uses CSRF cookie: `/sanctum/csrf-cookie`
- Never disable CSRF middleware globally

## Mass Assignment Protection

```php
// GOOD — explicit fillable
protected $fillable = ['name', 'email', 'phone'];

// GOOD — use validated data only
$user->update($request->validated());

// BAD — guarded empty = everything is fillable
protected $guarded = []; // NEVER in production

// BAD — using all input
$user->update($request->all()); // NEVER — includes unexpected fields
```

## File Upload Security

```php
public function rules(): array
{
    return [
        'document' => [
            'required',
            'file',
            'mimes:pdf,doc,docx',      // Whitelist extensions
            'max:10240',                 // Max 10MB
        ],
        'avatar' => [
            'required',
            'image',                     // Must be an image
            'mimes:jpg,png,webp',        // Whitelist formats
            'max:2048',                  // Max 2MB
            'dimensions:max_width=2000,max_height=2000',
        ],
    ];
}

// Store securely
$path = $request->file('document')->store('documents', 'private'); // Private disk
```

### File Upload Rules

- **Always validate file type AND size**
- Store uploads on a **non-public disk** when possible
- Generate random filenames — never use the original name for storage
- Check MIME type server-side, don't trust the client
- Set maximum file sizes in both validation AND php.ini/nginx config

## Security Headers

```php
// Middleware for security headers
final class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-XSS-Protection', '1; mode=block');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

        return $response;
    }
}
```

## Environment Security

- **Never commit `.env` files** to version control
- Use **strong `APP_KEY`** — generate with `php artisan key:generate`
- Set `APP_DEBUG=false` in production
- Set `APP_ENV=production` in production
- Use strong, unique passwords for all services (DB, Redis, etc.)
- Rotate secrets regularly
- Use vault services (AWS Secrets Manager, HashiCorp Vault) for sensitive credentials

## Password Handling

```php
// In AppServiceProvider::boot()
Password::defaults(function () {
    return Password::min(8)
        ->mixedCase()
        ->numbers()
        ->symbols()
        ->uncompromised(); // Check against breached password databases
});

// Usage in Form Request
'password' => ['required', 'confirmed', Password::defaults()],
```

## Rate Limiting

```php
// Define in AppServiceProvider
RateLimiter::for('login', function (Request $request) {
    return [
        Limit::perMinute(5)->by($request->ip()),
        Limit::perMinute(10)->by($request->input('email')),
    ];
});

// Apply to routes
Route::post('login', LoginController::class)->middleware('throttle:login');
```

````
