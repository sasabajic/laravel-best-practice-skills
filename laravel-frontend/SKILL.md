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

## Server-Side Rendering (SSR) with Inertia

### Why SSR

- **SEO:** Search engines can crawl fully rendered HTML without executing JavaScript
- **Initial load performance:** Users see content faster — HTML is pre-rendered on the server
- **Social sharing:** Open Graph meta tags are present in the initial response

### Enabling SSR in Inertia (Laravel + Vue)

```bash
# Install the SSR server dependencies
npm install @vue/server-renderer
```

```js
// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [
        laravel({
            input: 'resources/js/app.js',
            ssr: 'resources/js/ssr.js',
            refresh: true,
        }),
        vue(),
    ],
});
```

```js
// resources/js/ssr.js
import { createInertiaApp } from '@inertiajs/vue3';
import createServer from '@inertiajs/vue3/server';
import { renderToString } from '@vue/server-renderer';
import { createSSRApp, h } from 'vue';

createServer((page) =>
    createInertiaApp({
        page,
        render: renderToString,
        resolve: (name) => {
            const pages = import.meta.glob('./Pages/**/*.vue', { eager: true });
            return pages[`./Pages/${name}.vue`];
        },
        setup({ App, props, plugin }) {
            return createSSRApp({ render: () => h(App, props) })
                .use(plugin);
        },
    }),
);
```

### Enabling SSR in Inertia (Laravel + React)

```js
// resources/js/ssr.jsx
import { createInertiaApp } from '@inertiajs/react';
import createServer from '@inertiajs/react/server';
import ReactDOMServer from 'react-dom/server';

createServer((page) =>
    createInertiaApp({
        page,
        render: ReactDOMServer.renderToString,
        resolve: (name) => {
            const pages = import.meta.glob('./Pages/**/*.jsx', { eager: true });
            return pages[`./Pages/${name}.jsx`];
        },
        setup: ({ App, props }) => <App {...props} />,
    }),
);
```

### Inertia SSR Config

```php
<?php

declare(strict_types=1);

// config/inertia.php
return [
    'ssr' => [
        'enabled' => true,
        'url' => 'http://127.0.0.1:13714',
    ],
];
```

### Running the SSR Server

```bash
# Build the SSR bundle
npm run build

# Start the SSR server
php artisan inertia:start-ssr

# Stop the SSR server
php artisan inertia:stop-ssr
```

### When to Use SSR vs CSR

| Scenario | Recommendation |
|----------|---------------|
| Public marketing pages, blog, landing pages | **SSR** — SEO is critical |
| Admin dashboards, internal tools | **CSR** — no SEO needed |
| E-commerce product pages | **SSR** — SEO + performance |
| Authenticated app areas | **CSR** — faster navigation |

### SSR Rules

- Enable SSR only for pages that benefit from SEO or initial load performance
- Avoid using `window`, `document`, or browser-only APIs in SSR-rendered components — use `onMounted()` (Vue) or `useEffect()` (React) for client-only code
- Test SSR locally before deploying — run `php artisan inertia:start-ssr` and verify rendered HTML
- Use `Inertia::lazy()` and `Inertia::defer()` to reduce SSR payload size
- Cross-reference **laravel-performance** for caching strategies that complement SSR

## Progressive Web App (PWA) Setup

### What PWA Provides

- **Offline support:** Service workers cache assets and API responses for offline use
- **Install prompt:** Users can install the app to their home screen
- **Push notifications:** Re-engage users with web push notifications
- **Performance:** Precached assets load instantly on repeat visits

### Service Worker Setup

```js
// resources/js/service-worker.js
const CACHE_NAME = 'app-cache-v1';
const PRECACHE_URLS = [
    '/',
    '/offline',
    '/build/assets/app.css',
    '/build/assets/app.js',
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
    );
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request).then((cached) => {
            return cached || fetch(event.request).catch(() => {
                if (event.request.mode === 'navigate') {
                    return caches.match('/offline');
                }
            });
        })
    );
});
```

```js
// resources/js/app.js — register the service worker
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/service-worker.js')
            .then((registration) => {
                console.log('SW registered:', registration.scope);
            })
            .catch((error) => {
                console.error('SW registration failed:', error);
            });
    });
}
```

### Web Manifest Configuration

```json
// public/manifest.json
{
    "name": "My Laravel App",
    "short_name": "LaravelApp",
    "start_url": "/",
    "display": "standalone",
    "background_color": "#ffffff",
    "theme_color": "#4f46e5",
    "icons": [
        {
            "src": "/images/icons/icon-192x192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "/images/icons/icon-512x512.png",
            "sizes": "512x512",
            "type": "image/png"
        }
    ]
}
```

```blade
{{-- Include in your layout head --}}
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#4f46e5">
<link rel="apple-touch-icon" href="/images/icons/icon-192x192.png">
```

### Laravel PWA Package Options

```bash
# Option: use a community package for quick setup
composer require silviolleite/laravelpwa
php artisan vendor:publish --provider="LaravelPWA\Providers\LaravelPWAServiceProvider"
```

```php
<?php

declare(strict_types=1);

// config/laravelpwa.php — key settings
return [
    'name' => 'My Laravel App',
    'manifest' => [
        'display' => 'standalone',
        'theme_color' => '#4f46e5',
        'background_color' => '#ffffff',
    ],
];
```

### PWA Rules

- Always provide a fallback offline page at `/offline`
- Version your cache names (`app-cache-v1`, `app-cache-v2`) to bust stale caches on deploy
- Use a network-first strategy for API calls and a cache-first strategy for static assets
- Test with Chrome DevTools → Application → Service Workers and Lighthouse PWA audit
- Keep the web manifest `start_url` and `scope` consistent with your app routes
- Cross-reference **laravel-performance** for asset optimization and caching strategies that complement PWA
