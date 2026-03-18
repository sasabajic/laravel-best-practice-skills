---
name: laravel-frontend
description: Laravel frontend development best practices including Blade components, Livewire, Inertia.js with Vue/React, Vite asset bundling, Tailwind CSS integration, Alpine.js, and modern frontend patterns within Laravel applications.
---

# Laravel Frontend Best Practices

Follow these conventions when building frontend interfaces in Laravel projects.

## Blade Components

### Anonymous Components (preferred for simple UI)

```
resources/views/components/
├── alert.blade.php
├── button.blade.php
├── card.blade.php
├── forms/
│   ├── input.blade.php
│   ├── select.blade.php
│   └── textarea.blade.php
├── layouts/
│   ├── app.blade.php
│   └── guest.blade.php
└── ui/
    ├── avatar.blade.php
    ├── badge.blade.php
    └── modal.blade.php
```

```blade
{{-- resources/views/components/forms/input.blade.php --}}
@props([
    'name',
    'label' => null,
    'type' => 'text',
    'required' => false,
])

<div>
    @if($label)
        <label for="{{ $name }}" class="block text-sm font-medium text-gray-700">
            {{ $label }}
            @if($required) <span class="text-red-500">*</span> @endif
        </label>
    @endif

    <input
        type="{{ $type }}"
        name="{{ $name }}"
        id="{{ $name }}"
        value="{{ old($name, $attributes->get('value')) }}"
        {{ $attributes->merge(['class' => 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm']) }}
        @if($required) required @endif
    />

    @error($name)
        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
    @enderror
</div>
```

### Class-Based Components (for complex logic)

```php
<?php

declare(strict_types=1);

namespace App\View\Components;

use Illuminate\Contracts\View\View;
use Illuminate\View\Component;

final class Alert extends Component
{
    public function __construct(
        public readonly string $type = 'info',
        public readonly bool $dismissible = false,
    ) {}

    public function colorClasses(): string
    {
        return match ($this->type) {
            'success' => 'bg-green-50 text-green-800 border-green-200',
            'warning' => 'bg-yellow-50 text-yellow-800 border-yellow-200',
            'error' => 'bg-red-50 text-red-800 border-red-200',
            default => 'bg-blue-50 text-blue-800 border-blue-200',
        };
    }

    public function render(): View
    {
        return view('components.alert');
    }
}
```

### Blade Component Rules

- Use **anonymous components** for simple, presentational elements
- Use **class-based components** when logic is needed
- Always use `@props` to declare expected attributes
- Use `$attributes->merge()` for default CSS classes that can be overridden
- Use slots for flexible content: `{{ $slot }}`, `{{ $header }}`, `{{ $footer }}`
- Keep components small and reusable — compose larger layouts from smaller components
- Use `@error()` directive inside form components

## Layout Pattern

```blade
{{-- resources/views/components/layouts/app.blade.php --}}
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>{{ $title ?? config('app.name') }}</title>

    @vite(['resources/css/app.css', 'resources/js/app.js'])

    {{ $head ?? '' }}
</head>
<body class="font-sans antialiased bg-gray-100">
    @if(isset($header))
        <header>{{ $header }}</header>
    @endif

    <main>
        {{ $slot }}
    </main>

    {{ $scripts ?? '' }}
</body>
</html>
```

Usage:
```blade
<x-layouts.app title="Dashboard">
    <x-slot:header>
        <h1>Dashboard</h1>
    </x-slot:header>

    <div class="container mx-auto py-8">
        {{-- Page content --}}
    </div>
</x-layouts.app>
```

## Livewire (Full-Stack Components)

### Livewire Component Convention

```php
<?php

declare(strict_types=1);

namespace App\Livewire;

use App\Models\Order;
use Illuminate\Contracts\View\View;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Url;
use Livewire\Attributes\Validate;
use Livewire\Component;
use Livewire\WithPagination;

final class OrderTable extends Component
{
    use WithPagination;

    #[Url]
    public string $search = '';

    #[Url]
    public string $status = '';

    #[Url]
    public string $sortBy = 'created_at';

    #[Url]
    public string $sortDirection = 'desc';

    // Reset pagination when filters change
    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    public function updatedStatus(): void
    {
        $this->resetPage();
    }

    public function sort(string $column): void
    {
        if ($this->sortBy === $column) {
            $this->sortDirection = $this->sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            $this->sortBy = $column;
            $this->sortDirection = 'asc';
        }
    }

    #[Computed]
    public function orders()
    {
        return Order::query()
            ->with('user')
            ->when($this->search, fn ($q) => $q->where('number', 'like', "%{$this->search}%"))
            ->when($this->status, fn ($q) => $q->where('status', $this->status))
            ->orderBy($this->sortBy, $this->sortDirection)
            ->paginate(15);
    }

    public function render(): View
    {
        return view('livewire.order-table');
    }
}
```

### Livewire Rules

- Use **Livewire 3** syntax (attributes, not properties)
- Use `#[Url]` for query string parameters (bookmarkable filters)
- Use `#[Computed]` for derived data
- Use `#[Validate]` for inline validation
- Keep components focused — one responsibility per component
- Use `wire:model.live` only when real-time update is needed (debounce: `wire:model.live.debounce.300ms`)
- Use `wire:model` (deferred) by default for forms — updates on submit
- Dispatch events between components: `$this->dispatch('orderUpdated')`
- Use `#[On('eventName')]` to listen for events

## Inertia.js (SPA Experience)

### Controller Pattern with Inertia

```php
use Inertia\Inertia;
use Inertia\Response;

final class OrderController extends Controller
{
    public function index(): Response
    {
        return Inertia::render('Orders/Index', [
            'orders' => OrderResource::collection(
                Order::with('user')
                    ->latest()
                    ->paginate(15)
            ),
            'filters' => request()->only(['search', 'status']),
            // Lazy-loaded props — only loaded when needed
            'stats' => Inertia::lazy(fn () => [
                'total' => Order::count(),
                'pending' => Order::where('status', 'pending')->count(),
            ]),
        ]);
    }

    public function store(StoreOrderRequest $request): RedirectResponse
    {
        $order = $this->orderService->create($request->validated());

        return redirect()
            ->route('orders.show', $order)
            ->with('success', 'Order created successfully.');
    }
}
```

### Inertia Rules

- Always use **API Resources** to transform data for Inertia props
- Use `Inertia::lazy()` for data that's not always needed
- Use `Inertia::defer()` for data loaded after initial page render
- Share common data via `HandleInertiaRequests` middleware
- Use redirects with flash messages for form submissions
- Use partial reloads: `router.reload({ only: ['orders'] })`

## Vite Configuration

```js
// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
// import vue from '@vitejs/plugin-vue'; // For Vue
// import react from '@vitejs/plugin-react'; // For React

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.css',
                'resources/js/app.js',
            ],
            refresh: true, // Auto-refresh on file changes
        }),
        // vue(),
        // react(),
    ],
});
```

## Tailwind CSS Conventions

- Use **Tailwind CSS** for styling — utility-first approach
- Extract components with `@apply` sparingly (prefer Blade components)
- Use Tailwind's responsive prefixes: `sm:`, `md:`, `lg:`, `xl:`
- Use dark mode: `dark:` prefix
- Keep `tailwind.config.js` organized with custom theme extensions
- Use `class-variance-authority` or similar for component variants

```blade
{{-- Component with variant pattern --}}
@props([
    'variant' => 'primary',
    'size' => 'md',
])

@php
$classes = match ($variant) {
    'primary' => 'bg-indigo-600 text-white hover:bg-indigo-700',
    'secondary' => 'bg-gray-200 text-gray-800 hover:bg-gray-300',
    'danger' => 'bg-red-600 text-white hover:bg-red-700',
};

$sizes = match ($size) {
    'sm' => 'px-3 py-1.5 text-sm',
    'md' => 'px-4 py-2 text-base',
    'lg' => 'px-6 py-3 text-lg',
};
@endphp

<button {{ $attributes->merge(['class' => "inline-flex items-center rounded-md font-semibold transition {$classes} {$sizes}"]) }}>
    {{ $slot }}
</button>
```

## Alpine.js for Interactivity

Use **Alpine.js** for simple interactive behaviors that don't need Livewire:

```blade
{{-- Dropdown --}}
<div x-data="{ open: false }" @click.outside="open = false">
    <button @click="open = !open">Menu</button>
    <div x-show="open" x-transition>
        {{-- dropdown content --}}
    </div>
</div>

{{-- Confirmation dialog --}}
<button
    x-data
    @click="if (confirm('Are you sure?')) $wire.delete({{ $item->id }})"
>
    Delete
</button>
```
