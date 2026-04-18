---
name: laravel-localization
description: Laravel localization and multi-language best practices including translation files, locale middleware, language switching, date/number/currency formatting, pluralization, Enum label translations, and JSON language files. Activates when working with translations, localization, multi-language support, or i18n.
---

# Laravel Localization & Multi-Language Best Practices

Follow these conventions when adding multi-language support to Laravel applications. All examples target **Laravel 10+** with **PHP 8.1+**.

> See also: **laravel-general** skill for core conventions and project structure.

> See also: **laravel-testing** skill for testing strategies referenced in the testing section below.

> See also: **laravel-frontend** skill for Blade, Livewire, and Inertia patterns used with frontend translations.

---

## 1 · Translation File Organization

### PHP Translation Files (keyed translations)

```
lang/
├── en/
│   ├── auth.php
│   ├── messages.php
│   ├── pagination.php
│   ├── passwords.php
│   └── validation.php
├── fr/
│   ├── auth.php
│   ├── messages.php
│   ├── pagination.php
│   ├── passwords.php
│   └── validation.php
├── en.json          # JSON translations (short strings, UI labels)
└── fr.json
```

### PHP Keyed File Example

```php
<?php

declare(strict_types=1);

// lang/en/messages.php
return [
    'welcome' => 'Welcome, :name!',
    'order' => [
        'created' => 'Order #:id has been placed successfully.',
        'shipped' => 'Your order #:id has been shipped.',
        'cancelled' => 'Order #:id has been cancelled.',
    ],
    'items_count' => '{0} No items|{1} One item|[2,*] :count items',
];
```

### JSON Translation File Example

Use JSON files for simple UI strings that match the default language verbatim.

```json
// lang/en.json
{
    "Welcome back!": "Welcome back!",
    "Sign out": "Sign out",
    "Save changes": "Save changes",
    "No results found.": "No results found."
}
```

```json
// lang/fr.json
{
    "Welcome back!": "Bon retour !",
    "Sign out": "Se déconnecter",
    "Save changes": "Enregistrer les modifications",
    "No results found.": "Aucun résultat trouvé."
}
```

### GOOD — Organize by domain/feature

```php
// lang/en/orders.php   — order-specific strings
// lang/en/users.php    — user-specific strings
// lang/en/dashboard.php — dashboard UI strings
```

### BAD — Dump everything in one file

```php
// lang/en/messages.php with 500+ keys covering every feature ❌
```

---

## 2 · Translation Helpers

### `__()` — Universal Helper (preferred)

```php
<?php

declare(strict_types=1);

// Keyed translations (from PHP files)
echo __('messages.welcome', ['name' => $user->name]);

// JSON translations (literal string lookup)
echo __('Welcome back!');
```

### `trans()` — Alias (equivalent to `__()`)

```php
echo trans('messages.order.created', ['id' => $order->id]);
```

### `@lang` — Blade Directive (does NOT escape output)

```blade
{{-- Escaped (safe for user-facing output) --}}
{{ __('messages.welcome', ['name' => $user->name]) }}

{{-- Unescaped — only use when translation contains trusted HTML --}}
@lang('messages.welcome', ['name' => $user->name])
```

### `trans_choice()` — Pluralization

```php
echo trans_choice('messages.items_count', $count, ['count' => $count]);
```

### GOOD — Always pass replacements as the second argument

```php
__('orders.created', ['id' => $order->id]);
```

### BAD — String concatenation or interpolation with translations

```php
// ❌ Breaks when word order differs across languages
__('orders.created') . ' #' . $order->id;
```

---

## 3 · Locale Middleware & Language Switching

### Middleware to Set Locale

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class SetLocale
{
    /** @var list<string> */
    private const SUPPORTED_LOCALES = ['en', 'fr', 'de', 'es'];

    public function handle(Request $request, Closure $next): Response
    {
        $locale = $request->segment(1);

        if (is_string($locale) && in_array($locale, self::SUPPORTED_LOCALES, true)) {
            app()->setLocale($locale);
        }

        return $next($request);
    }
}
```

### Register in Bootstrap (Laravel 11+) or Kernel (Laravel 10)

```php
// bootstrap/app.php (Laravel 11+)
->withMiddleware(function (Middleware $middleware): void {
    $middleware->web(append: [
        \App\Http\Middleware\SetLocale::class,
    ]);
})
```

```php
// app/Http/Kernel.php (Laravel 10)
protected $middlewareGroups = [
    'web' => [
        // ... other middleware
        \App\Http\Middleware\SetLocale::class,
    ],
];
```

### Session-Based Locale Switching

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

final class LanguageController extends Controller
{
    /** @var list<string> */
    private const SUPPORTED_LOCALES = ['en', 'fr', 'de', 'es'];

    public function __invoke(Request $request, string $locale): RedirectResponse
    {
        abort_unless(in_array($locale, self::SUPPORTED_LOCALES, true), 400);

        $request->session()->put('locale', $locale);
        app()->setLocale($locale);

        return redirect()->back();
    }
}
```

### Session-Based Middleware Variant

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class SetLocaleFromSession
{
    public function handle(Request $request, Closure $next): Response
    {
        $locale = $request->session()->get('locale', config('app.locale'));

        if (is_string($locale)) {
            app()->setLocale($locale);
        }

        return $next($request);
    }
}
```

---

## 4 · URL-Based Locale (Prefix Routes)

### Route Group with Locale Prefix

```php
<?php

declare(strict_types=1);

use App\Http\Controllers\HomeController;
use App\Http\Controllers\OrderController;
use App\Http\Middleware\SetLocale;
use Illuminate\Support\Facades\Route;

Route::prefix('{locale}')
    ->where(['locale' => '[a-z]{2}'])
    ->middleware(SetLocale::class)
    ->group(function (): void {
        Route::get('/', HomeController::class)->name('home');
        Route::resource('orders', OrderController::class);
    });
```

### Generating Localized URLs

```php
<?php

declare(strict_types=1);

// Always include the locale when generating URLs
route('home', ['locale' => app()->getLocale()]);
route('orders.show', ['locale' => app()->getLocale(), 'order' => $order]);
```

### GOOD — Centralize supported locales in config

```php
// config/app.php
'locale' => 'en',
'fallback_locale' => 'en',
'available_locales' => ['en', 'fr', 'de', 'es'],
```

### BAD — Hardcode locale lists in multiple places

```php
// ❌ Duplicated in middleware, controller, routes…
if (in_array($locale, ['en', 'fr', 'de'])) { /* ... */ }
```

---

## 5 · Date, Number & Currency Formatting

### Date Formatting with Carbon

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Carbon\Carbon;

final class DateFormatter
{
    public function localized(Carbon $date, string $locale = null): string
    {
        $locale ??= app()->getLocale();

        return $date->locale($locale)->isoFormat('LL');
    }

    public function relative(Carbon $date, string $locale = null): string
    {
        $locale ??= app()->getLocale();

        return $date->locale($locale)->diffForHumans();
    }
}
```

### Number & Currency Formatting with NumberFormatter (intl extension)

```php
<?php

declare(strict_types=1);

namespace App\Services;

use NumberFormatter;

final class LocaleFormatter
{
    public function number(float $value, string $locale = null): string
    {
        $locale ??= app()->getLocale();
        $formatter = new NumberFormatter($locale, NumberFormatter::DECIMAL);

        return $formatter->format($value);
    }

    public function currency(float $value, string $currencyCode, string $locale = null): string
    {
        $locale ??= app()->getLocale();
        $formatter = new NumberFormatter($locale, NumberFormatter::CURRENCY);

        return $formatter->formatCurrency($value, $currencyCode);
    }

    public function percent(float $value, string $locale = null): string
    {
        $locale ??= app()->getLocale();
        $formatter = new NumberFormatter($locale, NumberFormatter::PERCENT);

        return $formatter->format($value);
    }
}
```

```php
// Usage:
$fmt = new LocaleFormatter();

$fmt->number(1234567.89, 'en');  // "1,234,567.89"
$fmt->number(1234567.89, 'de');  // "1.234.567,89"

$fmt->currency(49.99, 'USD', 'en');  // "$49.99"
$fmt->currency(49.99, 'EUR', 'de');  // "49,99 €"
```

> **Note:** The `intl` PHP extension is required for `NumberFormatter`. Ensure it is installed in all environments.

---

## 6 · Pluralization Rules

### Using `trans_choice()`

```php
// lang/en/cart.php
return [
    'items' => '{0} Your cart is empty|{1} You have one item in your cart|[2,*] You have :count items in your cart',
];
```

```php
trans_choice('cart.items', 0);  // "Your cart is empty"
trans_choice('cart.items', 1);  // "You have one item in your cart"
trans_choice('cart.items', 5, ['count' => 5]);  // "You have 5 items in your cart"
```

### JSON Pluralization

```json
// lang/en.json
{
    "{0} No notifications|{1} One notification|[2,*] :count notifications": "{0} No notifications|{1} One notification|[2,*] :count notifications"
}
```

### Languages with Complex Plural Rules (e.g., Arabic, Russian)

Laravel uses Symfony's translation component which supports all Unicode CLDR plural rules. Define all required plural forms for the target language.

```php
// lang/ru/messages.php
return [
    'apples' => ':count яблоко|:count яблока|:count яблок',
];
```

---

## 7 · Translating Enum Labels

### Backed Enum with Translated Labels

```php
<?php

declare(strict_types=1);

namespace App\Enums;

enum OrderStatus: string
{
    case Pending = 'pending';
    case Processing = 'processing';
    case Shipped = 'shipped';
    case Delivered = 'delivered';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return __("enums.order_status.{$this->value}");
    }

    /** @return array<string, string> */
    public static function options(): array
    {
        return array_combine(
            array_column(self::cases(), 'value'),
            array_map(fn (self $case): string => $case->label(), self::cases()),
        );
    }
}
```

```php
// lang/en/enums.php
return [
    'order_status' => [
        'pending' => 'Pending',
        'processing' => 'Processing',
        'shipped' => 'Shipped',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
    ],
];
```

```php
// lang/fr/enums.php
return [
    'order_status' => [
        'pending' => 'En attente',
        'processing' => 'En cours de traitement',
        'shipped' => 'Expédié',
        'delivered' => 'Livré',
        'cancelled' => 'Annulé',
    ],
];
```

### GOOD — Centralize all enum translations in `enums.php`

### BAD — Hardcode display labels inside the Enum

```php
// ❌ Not translatable
public function label(): string
{
    return match ($this) {
        self::Pending => 'Pending',
        self::Shipped => 'Shipped',
    };
}
```

> See also: **laravel-code-style** skill for Enum conventions.

---

## 8 · Translating Validation Messages

### Custom Validation Language File

```php
// lang/en/validation.php
return [
    'required' => 'The :attribute field is required.',
    'email' => 'The :attribute must be a valid email address.',
    'max' => [
        'string' => 'The :attribute must not exceed :max characters.',
    ],

    // Custom attribute names for cleaner messages
    'attributes' => [
        'email' => 'email address',
        'first_name' => 'first name',
        'phone_number' => 'phone number',
    ],

    // Custom messages for specific field + rule combinations
    'custom' => [
        'email' => [
            'unique' => 'An account with this email already exists.',
        ],
    ],
];
```

### Form Request with Translated Messages

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class StoreOrderRequest extends FormRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'product_id' => ['required', 'exists:products,id'],
            'quantity' => ['required', 'integer', 'min:1'],
            'notes' => ['nullable', 'string', 'max:500'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'product_id.required' => __('validation.custom.product_id.required'),
            'quantity.min' => __('validation.custom.quantity.min'),
        ];
    }

    /** @return array<string, string> */
    public function attributes(): array
    {
        return [
            'product_id' => __('validation.attributes.product_id'),
            'quantity' => __('validation.attributes.quantity'),
        ];
    }
}
```

---

## 9 · Translating Notifications & Mail

### Translatable Notification

```php
<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

final class OrderShippedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly Order $order,
    ) {}

    /** @return list<string> */
    public function via(mixed $notifiable): array
    {
        return ['mail', 'database'];
    }

    public function toMail(mixed $notifiable): MailMessage
    {
        return (new MailMessage())
            ->subject(__('notifications.order_shipped.subject', ['id' => $this->order->id]))
            ->greeting(__('notifications.order_shipped.greeting', ['name' => $notifiable->name]))
            ->line(__('notifications.order_shipped.line1', ['id' => $this->order->id]))
            ->action(__('notifications.order_shipped.action'), route('orders.show', $this->order))
            ->line(__('notifications.order_shipped.thanks'));
    }

    /** @return array<string, mixed> */
    public function toArray(mixed $notifiable): array
    {
        return [
            'order_id' => $this->order->id,
            'message' => __('notifications.order_shipped.line1', ['id' => $this->order->id]),
        ];
    }
}
```

```php
// lang/en/notifications.php
return [
    'order_shipped' => [
        'subject' => 'Your Order #:id Has Been Shipped',
        'greeting' => 'Hello :name,',
        'line1' => 'Great news! Your order #:id is on its way.',
        'action' => 'Track Order',
        'thanks' => 'Thank you for shopping with us!',
    ],
];
```

### Setting Locale for Queued Notifications

```php
<?php

declare(strict_types=1);

// Set the preferred locale on the notifiable model
namespace App\Models;

use Illuminate\Contracts\Translation\HasLocalePreference;
use Illuminate\Foundation\Auth\User as Authenticatable;

final class User extends Authenticatable implements HasLocalePreference
{
    public function preferredLocale(): string
    {
        return $this->locale ?? config('app.locale');
    }
}
```

Laravel automatically uses the notifiable's preferred locale when sending queued notifications.

> See also: **laravel-notifications** skill (if available) for full notification patterns.

---

## 10 · Database Content Translation Strategies

### Strategy A — JSON Column (simple, no extra tables)

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

final class Product extends Model
{
    /** @var list<string> */
    protected $fillable = [
        'name',
        'description',
        'price',
    ];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'name' => 'array',
            'description' => 'array',
            'price' => 'decimal:2',
        ];
    }

    public function getTranslatedName(string $locale = null): string
    {
        $locale ??= app()->getLocale();
        $fallback = config('app.fallback_locale');

        return $this->name[$locale] ?? $this->name[$fallback] ?? '';
    }

    public function getTranslatedDescription(string $locale = null): string
    {
        $locale ??= app()->getLocale();
        $fallback = config('app.fallback_locale');

        return $this->description[$locale] ?? $this->description[$fallback] ?? '';
    }
}
```

```php
// Migration
Schema::create('products', function (Blueprint $table): void {
    $table->id();
    $table->json('name');          // {"en": "Widget", "fr": "Gadget"}
    $table->json('description');   // {"en": "A fine widget", "fr": "Un beau gadget"}
    $table->decimal('price', 10, 2);
    $table->timestamps();
});
```

### Strategy B — Dedicated Translation Table (scalable, queryable)

```php
// Migration
Schema::create('product_translations', function (Blueprint $table): void {
    $table->id();
    $table->foreignId('product_id')->constrained()->cascadeOnDelete();
    $table->string('locale', 5);
    $table->string('name');
    $table->text('description')->nullable();
    $table->unique(['product_id', 'locale']);
    $table->timestamps();
});
```

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

final class Product extends Model
{
    /** @return HasMany<ProductTranslation> */
    public function translations(): HasMany
    {
        return $this->hasMany(ProductTranslation::class);
    }

    /** @return HasOne<ProductTranslation> */
    public function translation(): HasOne
    {
        return $this->hasOne(ProductTranslation::class)
            ->where('locale', app()->getLocale());
    }

    public function getTranslatedName(): string
    {
        return $this->translation?->name
            ?? $this->translations->firstWhere('locale', config('app.fallback_locale'))?->name
            ?? '';
    }
}
```

### GOOD — Pick one strategy per project and stay consistent

### BAD — Mix JSON columns and translation tables within the same domain

> See also: **laravel-eloquent-database** skill for model and migration conventions.

---

## 11 · Frontend Translations

### Passing Translations to JavaScript (Blade)

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use Illuminate\Support\Facades\File;
use Illuminate\View\View;

final class AppController extends Controller
{
    public function index(): View
    {
        return view('app', [
            'translations' => $this->loadTranslations(),
            'locale' => app()->getLocale(),
        ]);
    }

    /** @return array<string, mixed> */
    private function loadTranslations(): array
    {
        $locale = app()->getLocale();
        $path = lang_path("{$locale}.json");

        if (File::exists($path)) {
            return json_decode(File::get($path), true, 512, JSON_THROW_ON_ERROR);
        }

        return [];
    }
}
```

```blade
{{-- In your layout --}}
<script>
    window.__translations = @json($translations);
    window.__locale = @json($locale);
</script>
```

```javascript
// resources/js/i18n.js
export function __(key, replacements = {}) {
    let translation = window.__translations?.[key] ?? key;

    Object.entries(replacements).forEach(([placeholder, value]) => {
        translation = translation.replace(`:${placeholder}`, value);
    });

    return translation;
}
```

### Inertia.js — Share Translations via HandleInertiaRequests

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;
use Inertia\Middleware;

final class HandleInertiaRequests extends Middleware
{
    /** @return array<string, mixed> */
    public function share(Request $request): array
    {
        return array_merge(parent::share($request), [
            'locale' => app()->getLocale(),
            'translations' => $this->loadTranslations(),
        ]);
    }

    /** @return array<string, mixed> */
    private function loadTranslations(): array
    {
        $locale = app()->getLocale();
        $path = lang_path("{$locale}.json");

        if (File::exists($path)) {
            return json_decode(File::get($path), true, 512, JSON_THROW_ON_ERROR);
        }

        return [];
    }
}
```

### Livewire — Use `__()` Directly in Blade

Livewire components render via Blade, so use standard `{{ __('key') }}` syntax. No extra setup needed.

```blade
{{-- Livewire component view --}}
<div>
    <h2>{{ __('dashboard.title') }}</h2>
    <p>{{ trans_choice('dashboard.notifications', $count, ['count' => $count]) }}</p>
</div>
```

> See also: **laravel-frontend** skill for Inertia, Livewire, and Blade component patterns.

---

## 12 · Filament Localization

Filament 3 has built-in localization support. Translations for panel chrome (buttons, labels, table headers) are handled by Filament's own language files.

### Translate Custom Labels in Resources

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Models\Product;
use Filament\Resources\Resource;

final class ProductResource extends Resource
{
    protected static ?string $model = Product::class;

    public static function getModelLabel(): string
    {
        return __('filament.resources.product.label');
    }

    public static function getPluralModelLabel(): string
    {
        return __('filament.resources.product.plural_label');
    }

    public static function getNavigationLabel(): string
    {
        return __('filament.resources.product.navigation');
    }
}
```

### Publish Filament Language Files

```bash
php artisan vendor:publish --tag=filament-translations
```

> See also: **laravel-filament** skill for full Filament resource and panel configuration.

---

## 13 · Testing Translations

### Pest Tests for Localization

```php
<?php

declare(strict_types=1);

use App\Enums\OrderStatus;

// Verify translations exist for all supported locales
it('has translations for all supported locales', function (string $locale): void {
    $path = lang_path("{$locale}.json");

    expect(file_exists($path))->toBeTrue("Missing JSON translation file for locale: {$locale}");
})->with(['en', 'fr', 'de', 'es']);

// Verify Enum label translations
it('translates all order status labels', function (string $locale): void {
    app()->setLocale($locale);

    foreach (OrderStatus::cases() as $case) {
        $label = $case->label();

        expect($label)->not->toBe("enums.order_status.{$case->value}",
            "Missing translation for OrderStatus::{$case->name} in locale '{$locale}'"
        );
    }
})->with(['en', 'fr']);

// Test middleware sets locale correctly
it('sets the application locale from the URL prefix', function (): void {
    $this->get('/fr/home')
        ->assertOk();

    expect(app()->getLocale())->toBe('fr');
});

// Test locale switching
it('switches locale via session', function (): void {
    $this->post('/language/fr')
        ->assertRedirect();

    $this->get('/dashboard')
        ->assertSessionHas('locale', 'fr');
});

// Test translated validation messages
it('returns translated validation errors', function (): void {
    app()->setLocale('fr');

    $this->postJson('/api/orders', [])
        ->assertStatus(422)
        ->assertJsonValidationErrors(['product_id']);
});
```

### GOOD — Test that every translation key resolves to a real string

### BAD — Only testing the default locale

```php
// ❌ Never validates that French, German, etc. translations actually exist
it('shows welcome message', function (): void {
    $this->get('/')->assertSee('Welcome');
});
```

> See also: **laravel-testing** skill for Pest conventions and test organization.

---

## Quick Reference

| Task | Approach |
|---|---|
| Simple UI string | JSON file + `__('string')` |
| Keyed, structured translation | PHP file + `__('file.key')` |
| Pluralization | `trans_choice()` with pipe syntax |
| Enum labels | `__("enums.{enum}.{value}")` in Enum method |
| Date formatting | `Carbon::locale($locale)->isoFormat()` |
| Number/Currency formatting | `NumberFormatter` (intl extension) |
| Validation messages | `lang/{locale}/validation.php` |
| Notification/Mail content | `__()` inside `toMail()` / `toArray()` |
| Database content | JSON column or dedicated translation table |
| Frontend (Blade) | `{{ __('key') }}` |
| Frontend (Inertia) | Share via `HandleInertiaRequests` middleware |
| Frontend (Livewire) | Standard `__()` in Blade views |
| Filament panels | `getModelLabel()` + published translations |
| Locale detection | Middleware reading URL segment or session |
