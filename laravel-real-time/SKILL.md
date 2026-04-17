---
name: laravel-real-time
description: Laravel real-time features and broadcasting best practices including Laravel Reverb setup, Echo configuration, public/private/presence channels, event broadcasting, WebSocket authentication, real-time notifications, and whisper events. Activates when working with broadcasting, WebSockets, real-time features, Reverb, or Echo.
---

# Laravel Real-Time & Broadcasting Best Practices

Follow these conventions when building real-time features in Laravel. **Laravel Reverb** is the recommended first-party WebSocket server.

## Laravel Reverb — Installation & Configuration

Reverb is Laravel's first-party, high-performance WebSocket server. Always prefer Reverb over third-party services like Pusher for new projects.

### Installation

```bash
php artisan install:broadcasting
```

This command scaffolds everything: Reverb config, Echo client, broadcasting routes, and environment variables.

### Environment Configuration

```env
BROADCAST_CONNECTION=reverb

REVERB_APP_ID=my-app
REVERB_APP_KEY=your-reverb-key
REVERB_APP_SECRET=your-reverb-secret
REVERB_HOST="localhost"
REVERB_PORT=8080
REVERB_SCHEME=https

# Frontend Echo connection (exposed to Vite)
VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
VITE_REVERB_HOST="${REVERB_HOST}"
VITE_REVERB_PORT="${REVERB_PORT}"
VITE_REVERB_SCHEME="${REVERB_SCHEME}"
```

### Running Reverb

```bash
# Development
php artisan reverb:start --debug

# Production (use Supervisor)
php artisan reverb:start
```

### Supervisor Configuration for Production

```ini
[program:reverb]
command=php /var/www/app/artisan reverb:start
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/www/app/storage/logs/reverb.log
stopwaitsecs=3600
```

### Reverb vs Pusher

| Feature | Reverb | Pusher |
|---------|--------|--------|
| Hosting | Self-hosted (your server) | Cloud-hosted (third-party) |
| Cost | Free (open-source) | Pay per connection/message |
| Latency | Low (same infrastructure) | Depends on region |
| Data privacy | Full control | Third-party processes data |
| Scaling | Horizontal with Redis | Built-in |
| Setup effort | Requires Supervisor/process manager | Zero infrastructure |

**Use Reverb** for most projects. Consider Pusher only when you need zero infrastructure management or global CDN-backed delivery.

## Broadcasting Setup

### Config — `config/broadcasting.php`

```php
'connections' => [
    'reverb' => [
        'driver' => 'reverb',
        'key' => env('REVERB_APP_KEY'),
        'secret' => env('REVERB_APP_SECRET'),
        'app_id' => env('REVERB_APP_ID'),
        'options' => [
            'host' => env('REVERB_HOST'),
            'port' => env('REVERB_PORT', 443),
            'scheme' => env('REVERB_SCHEME', 'https'),
            'useTLS' => env('REVERB_SCHEME', 'https') === 'https',
        ],
        'client_options' => [],
    ],
],
```

### Enable Broadcasting

```php
// bootstrap/app.php — broadcasting is auto-enabled with install:broadcasting
// Ensure BroadcastServiceProvider is loaded (automatic in Laravel 11+)
```

## Event Broadcasting

### ShouldBroadcast vs ShouldBroadcastNow

Use `ShouldBroadcast` for queue-dispatched broadcasts (recommended). Use `ShouldBroadcastNow` only when real-time latency is critical and queue delay is unacceptable.

```php
<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

final class OrderStatusUpdated implements ShouldBroadcast
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(
        public readonly Order $order,
    ) {}

    /** @return array<int, Channel> */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('orders.'.$this->order->id),
            new PrivateChannel('users.'.$this->order->user_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'order.status.updated';
    }

    /** @return array<string, mixed> */
    public function broadcastWith(): array
    {
        return [
            'id' => $this->order->id,
            'number' => $this->order->number,
            'status' => $this->order->status->value,
            'status_label' => $this->order->status->label(),
            'updated_at' => $this->order->updated_at->toIso8601String(),
        ];
    }

    public function broadcastWhen(): bool
    {
        return $this->order->wasChanged('status');
    }
}
```

### Broadcasting Rules

- **Always define `broadcastAs()`** — use dot-notation naming: `order.status.updated`
- **Always define `broadcastWith()`** — control the payload explicitly, never send the entire model
- Use `broadcastWhen()` to conditionally broadcast
- Use `ShouldBroadcast` (queued) by default — use `ShouldBroadcastNow` sparingly
- Broadcast to multiple channels when different consumers need the same event

### GOOD — Controlled broadcast payload

```php
public function broadcastWith(): array
{
    return [
        'id' => $this->order->id,
        'status' => $this->order->status->value,
        'total' => (float) $this->order->total,
    ];
}
```

### BAD — Leaking entire model to frontend

```php
// Never do this — exposes all model attributes, including sensitive data
public function broadcastWith(): array
{
    return $this->order->toArray();
}
```

## Broadcasting with Queues

Broadcast events should use a dedicated queue to avoid blocking other jobs.

```php
<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Queue\SerializesModels;

final class OrderShipped implements ShouldBroadcast
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public string $queue = 'broadcasts';

    public int $tries = 3;

    public int $backoff = 5;

    public function __construct(
        public readonly Order $order,
    ) {}

    /** @return array<int, \Illuminate\Broadcasting\Channel> */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('orders.'.$this->order->id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'order.shipped';
    }

    /** @return array<string, mixed> */
    public function broadcastWith(): array
    {
        return [
            'id' => $this->order->id,
            'number' => $this->order->number,
            'shipped_at' => $this->order->shipped_at?->toIso8601String(),
            'tracking_number' => $this->order->tracking_number,
        ];
    }
}
```

Run a dedicated queue worker for broadcasts:

```bash
php artisan queue:work --queue=broadcasts
```

> See also: **laravel-performance** skill for queue optimization and worker configuration.

## Channel Types & Authorization

### Public Channels

Anyone can listen — no authentication required. Use for publicly visible data.

```php
// In the event
public function broadcastOn(): array
{
    return [
        new Channel('orders'),
    ];
}
```

### Private Channels

Only authenticated, authorized users can listen.

```php
// In the event
public function broadcastOn(): array
{
    return [
        new PrivateChannel('orders.'.$this->order->id),
    ];
}
```

### Presence Channels

Like private channels, but track who is currently subscribed. Use for "user is online" or "who is viewing this page" features.

```php
use Illuminate\Broadcasting\PresenceChannel;

public function broadcastOn(): array
{
    return [
        new PresenceChannel('orders.'.$this->order->id),
    ];
}
```

### Channel Authorization — `routes/channels.php`

```php
<?php

declare(strict_types=1);

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

// Private channel — return bool
Broadcast::channel('orders.{orderId}', function (User $user, int $orderId): bool {
    $order = Order::find($orderId);

    return $order !== null && $user->id === $order->user_id;
});

// User-specific channel
Broadcast::channel('users.{userId}', function (User $user, int $userId): bool {
    return $user->id === $userId;
});

// Presence channel — return user data array (or false to deny)
Broadcast::channel('orders.{orderId}.editors', function (User $user, int $orderId): array|false {
    $order = Order::find($orderId);

    if ($order === null || $user->id !== $order->user_id) {
        return false;
    }

    return [
        'id' => $user->id,
        'name' => $user->name,
        'avatar' => $user->avatar_url,
    ];
});

// Admin dashboard presence channel
Broadcast::channel('admin.dashboard', function (User $user): array|false {
    if (! $user->isAdmin()) {
        return false;
    }

    return [
        'id' => $user->id,
        'name' => $user->name,
    ];
});
```

### Authorization Rules

- **Private channels** — callback returns `bool`
- **Presence channels** — callback returns `array` (user info) or `false` (denied)
- Always validate ownership or permissions in channel authorization
- Keep channel authorization logic simple — delegate complex checks to Policies

> See also: **laravel-security** skill for authorization patterns and Policies.

### GOOD — Authorization with ownership check

```php
Broadcast::channel('orders.{orderId}', function (User $user, int $orderId): bool {
    return Order::where('id', $orderId)
        ->where('user_id', $user->id)
        ->exists();
});
```

### BAD — No authorization check

```php
// Never allow all authenticated users to access any resource channel
Broadcast::channel('orders.{orderId}', function (User $user, int $orderId): bool {
    return true;
});
```

## Laravel Echo — JavaScript Client Setup

### Installation

```bash
npm install laravel-echo pusher-js
```

> Even with Reverb, `pusher-js` is the underlying WebSocket client used by Echo.

### Echo Configuration — `resources/js/echo.js`

```javascript
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: import.meta.env.VITE_REVERB_PORT ?? 80,
    wssPort: import.meta.env.VITE_REVERB_PORT ?? 443,
    forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],
});
```

### TypeScript Echo Configuration

```typescript
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

declare global {
    interface Window {
        Pusher: typeof Pusher;
        Echo: Echo<'reverb'>;
    }
}

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: Number(import.meta.env.VITE_REVERB_PORT ?? 80),
    wssPort: Number(import.meta.env.VITE_REVERB_PORT ?? 443),
    forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],
});
```

## Listening for Events in Frontend

### Blade + Alpine.js

```html
<div
    x-data="{ status: '{{ $order->status->value }}', notification: '' }"
    x-init="
        Echo.private('orders.{{ $order->id }}')
            .listen('.order.status.updated', (event) => {
                status = event.status;
                notification = `Order updated to ${event.status_label}`;
                setTimeout(() => notification = '', 5000);
            });
    "
>
    <p>Status: <span x-text="status"></span></p>
    <div x-show="notification" x-text="notification" class="alert alert-info"></div>
</div>
```

> Note the `.` prefix in `.order.status.updated` — required when using `broadcastAs()` to prevent Echo from prepending the namespace.

### Livewire

Livewire has built-in Echo integration using the `#[On]` attribute for events dispatched from the server, but for broadcast events, use `getListeners()`:

```php
<?php

declare(strict_types=1);

namespace App\Livewire;

use App\Models\Order;
use Livewire\Component;

final class OrderTracker extends Component
{
    public Order $order;

    /** @return array<string, string> */
    public function getListeners(): array
    {
        return [
            "echo-private:orders.{$this->order->id},.order.status.updated" => 'handleStatusUpdate',
            "echo-private:orders.{$this->order->id},.order.shipped" => 'handleShipped',
        ];
    }

    public function handleStatusUpdate(array $payload): void
    {
        $this->order->refresh();
    }

    public function handleShipped(array $payload): void
    {
        $this->order->refresh();
        $this->dispatch('notify', message: 'Your order has been shipped!');
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.order-tracker');
    }
}
```

### Vue.js (Composition API)

```typescript
// composables/useOrderChannel.ts
import { ref, onMounted, onUnmounted } from 'vue';

interface OrderStatusEvent {
    id: number;
    number: string;
    status: string;
    status_label: string;
    updated_at: string;
}

export function useOrderChannel(orderId: number) {
    const status = ref<string>('');
    const lastUpdate = ref<string>('');

    onMounted(() => {
        window.Echo.private(`orders.${orderId}`)
            .listen('.order.status.updated', (event: OrderStatusEvent) => {
                status.value = event.status;
                lastUpdate.value = event.updated_at;
            })
            .listen('.order.shipped', (event: { tracking_number: string }) => {
                // Handle shipped event
            });
    });

    onUnmounted(() => {
        window.Echo.leave(`orders.${orderId}`);
    });

    return { status, lastUpdate };
}
```

### React (Custom Hook)

```typescript
// hooks/useOrderChannel.ts
import { useEffect, useState } from 'react';

interface OrderStatusEvent {
    id: number;
    status: string;
    status_label: string;
    updated_at: string;
}

export function useOrderChannel(orderId: number) {
    const [status, setStatus] = useState<string>('');

    useEffect(() => {
        const channel = window.Echo.private(`orders.${orderId}`);

        channel.listen('.order.status.updated', (event: OrderStatusEvent) => {
            setStatus(event.status);
        });

        return () => {
            window.Echo.leave(`orders.${orderId}`);
        };
    }, [orderId]);

    return { status };
}
```

### Frontend Rules

- **Always call `Echo.leave()`** when a component unmounts — prevents memory leaks and ghost subscriptions
- Use the `.` prefix when listening for events that define `broadcastAs()`
- Prefer composables/hooks to encapsulate channel logic — keep components clean
- Type your event payloads in TypeScript

## Presence Channels for User Tracking

Presence channels are ideal for "who's online" features, collaborative editing indicators, and live dashboards.

### Listening to Presence Events

```typescript
// Track who is viewing an order
window.Echo.join(`orders.${orderId}.editors`)
    .here((users: UserInfo[]) => {
        // Called once on join — full list of current members
        onlineUsers.value = users;
    })
    .joining((user: UserInfo) => {
        // A user joined
        onlineUsers.value.push(user);
    })
    .leaving((user: UserInfo) => {
        // A user left
        onlineUsers.value = onlineUsers.value.filter(u => u.id !== user.id);
    })
    .listen('.order.status.updated', (event: OrderStatusEvent) => {
        // Regular events still work on presence channels
    });
```

### Vue Composable for Presence

```typescript
// composables/usePresenceChannel.ts
import { ref, onMounted, onUnmounted } from 'vue';

interface PresenceUser {
    id: number;
    name: string;
    avatar: string;
}

export function usePresenceChannel(channelName: string) {
    const users = ref<PresenceUser[]>([]);

    onMounted(() => {
        window.Echo.join(channelName)
            .here((members: PresenceUser[]) => {
                users.value = members;
            })
            .joining((user: PresenceUser) => {
                users.value.push(user);
            })
            .leaving((user: PresenceUser) => {
                users.value = users.value.filter(u => u.id !== user.id);
            });
    });

    onUnmounted(() => {
        window.Echo.leave(channelName);
    });

    return { users };
}
```

## Whisper Events — Client-to-Client

Whisper events go directly between clients through the WebSocket server **without hitting your Laravel backend**. Use for ephemeral UI states like typing indicators or cursor positions.

> Whisper events require private or presence channels.

### Sending Whisper Events

```typescript
// Typing indicator — client side
const channel = window.Echo.private(`orders.${orderId}.chat`);

// Send whisper
channel.whisper('typing', {
    user: { id: 1, name: 'John' },
});

// Listen for whisper
channel.listenForWhisper('typing', (event: { user: { id: number; name: string } }) => {
    showTypingIndicator(event.user);
});
```

### Typing Indicator Example (Vue)

```typescript
// composables/useTypingIndicator.ts
import { ref, watch } from 'vue';

export function useTypingIndicator(channelName: string, currentUser: { id: number; name: string }) {
    const typingUsers = ref<Map<number, string>>(new Map());
    const isTyping = ref(false);
    let typingTimeout: ReturnType<typeof setTimeout>;

    const channel = window.Echo.private(channelName);

    channel.listenForWhisper('typing', (event: { user: { id: number; name: string } }) => {
        typingUsers.value.set(event.user.id, event.user.name);

        setTimeout(() => {
            typingUsers.value.delete(event.user.id);
        }, 3000);
    });

    watch(isTyping, (value) => {
        if (value) {
            channel.whisper('typing', { user: currentUser });
        }
    });

    function onInput(): void {
        isTyping.value = true;
        clearTimeout(typingTimeout);
        typingTimeout = setTimeout(() => {
            isTyping.value = false;
        }, 1000);
    }

    return { typingUsers, onInput };
}
```

### Whisper Rules

- Use whispers **only for ephemeral UI state** — typing, cursor position, focus
- **Never use whispers for data mutations** — always go through your API for state changes
- Whispers are not persisted and cannot be replayed
- Only private and presence channels support whispers

## Real-Time Notifications Integration

Combine Laravel's notification system with broadcasting for real-time user notifications.

### Broadcast Notification

```php
<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\BroadcastMessage;
use Illuminate\Notifications\Notification;

final class OrderShippedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly Order $order,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['database', 'broadcast'];
    }

    public function toBroadcast(object $notifiable): BroadcastMessage
    {
        return new BroadcastMessage([
            'id' => $this->id,
            'type' => 'order_shipped',
            'order_id' => $this->order->id,
            'order_number' => $this->order->number,
            'message' => "Your order #{$this->order->number} has been shipped!",
            'created_at' => now()->toIso8601String(),
        ]);
    }

    public function toArray(object $notifiable): array
    {
        return [
            'order_id' => $this->order->id,
            'order_number' => $this->order->number,
            'message' => "Your order #{$this->order->number} has been shipped!",
        ];
    }
}
```

### Listening for Notifications on Frontend

Laravel broadcasts notifications on a private channel named `App.Models.User.{id}` by default.

```typescript
// Listen for all notifications for the authenticated user
window.Echo.private(`App.Models.User.${userId}`)
    .notification((notification: {
        id: string;
        type: string;
        order_id: number;
        order_number: string;
        message: string;
    }) => {
        showToast(notification.message);
        incrementUnreadCount();
    });
```

### Custom Notification Channel Name

```php
// In User model
public function receivesBroadcastNotificationsOn(): string
{
    return 'users.'.$this->id.'.notifications';
}
```

```typescript
// Frontend listens on custom channel
window.Echo.private(`users.${userId}.notifications`)
    .notification((notification) => {
        // Handle notification
    });
```

> See also: **laravel-notifications** skill for notification best practices, channels, and queuing.

## Dispatching Broadcast Events

### From Services or Controllers

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\OrderStatus;
use App\Events\OrderStatusUpdated;
use App\Events\OrderShipped;
use App\Models\Order;
use App\Notifications\OrderShippedNotification;

final class OrderService
{
    public function updateStatus(Order $order, OrderStatus $status): Order
    {
        $order->update(['status' => $status]);

        OrderStatusUpdated::dispatch($order);

        if ($status === OrderStatus::Shipped) {
            OrderShipped::dispatch($order);
            $order->user->notify(new OrderShippedNotification($order));
        }

        return $order;
    }
}
```

> See also: **laravel-architecture** skill for service layer patterns.

### GOOD — Dispatch events from service layer

```php
// Service handles business logic and dispatches events
$this->orderService->updateStatus($order, OrderStatus::Shipped);
```

### BAD — Broadcast directly from controller

```php
// Don't broadcast from controllers — use events and services
public function update(Request $request, Order $order): JsonResponse
{
    $order->update($request->validated());
    broadcast(new OrderStatusUpdated($order))->toOthers(); // Logic leaking into controller
    return response()->json($order);
}
```

## Excluding the Current User — `toOthers()`

When a user triggers an action, exclude them from receiving the broadcast to avoid duplicate UI updates:

```php
// In controller — after the user's own action
broadcast(new OrderStatusUpdated($order))->toOthers();
```

Echo sends an `X-Socket-ID` header with requests. Configure your HTTP client to include it:

```typescript
// Axios — automatic with Laravel Echo
window.axios.defaults.headers.common['X-Socket-Id'] = window.Echo.socketId();
```

## Testing Broadcasting

### Assert Events Are Broadcast

```php
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Events\OrderStatusUpdated;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

final class OrderBroadcastTest extends TestCase
{
    public function test_order_status_update_broadcasts_event(): void
    {
        Event::fake([OrderStatusUpdated::class]);

        $user = User::factory()->create();
        $order = Order::factory()->for($user)->create([
            'status' => OrderStatus::Pending,
        ]);

        $this->actingAs($user)
            ->patchJson("/api/v1/orders/{$order->id}/status", [
                'status' => OrderStatus::Processing->value,
            ])
            ->assertOk();

        Event::assertDispatched(OrderStatusUpdated::class, function ($event) use ($order) {
            return $event->order->id === $order->id;
        });
    }

    public function test_broadcast_event_has_correct_channels(): void
    {
        $order = Order::factory()->create();
        $event = new OrderStatusUpdated($order);

        $channels = $event->broadcastOn();

        $this->assertCount(2, $channels);
        $this->assertEquals("private-orders.{$order->id}", $channels[0]->name);
        $this->assertEquals("private-users.{$order->user_id}", $channels[1]->name);
    }

    public function test_broadcast_event_has_correct_payload(): void
    {
        $order = Order::factory()->create([
            'number' => 'ORD-001',
            'status' => OrderStatus::Processing,
        ]);

        $event = new OrderStatusUpdated($order);
        $payload = $event->broadcastWith();

        $this->assertEquals($order->id, $payload['id']);
        $this->assertEquals('ORD-001', $payload['number']);
        $this->assertEquals(OrderStatus::Processing->value, $payload['status']);
        $this->assertArrayNotHasKey('user_id', $payload);
    }

    public function test_broadcast_event_name(): void
    {
        $order = Order::factory()->create();
        $event = new OrderStatusUpdated($order);

        $this->assertEquals('order.status.updated', $event->broadcastAs());
    }
}
```

### Test Channel Authorization

```php
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Tests\TestCase;

final class BroadcastAuthorizationTest extends TestCase
{
    public function test_user_can_access_own_order_channel(): void
    {
        $user = User::factory()->create();
        $order = Order::factory()->for($user)->create();

        $this->actingAs($user)
            ->post('/broadcasting/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => "private-orders.{$order->id}",
            ])
            ->assertOk();
    }

    public function test_user_cannot_access_other_users_order_channel(): void
    {
        $user = User::factory()->create();
        $otherUser = User::factory()->create();
        $order = Order::factory()->for($otherUser)->create();

        $this->actingAs($user)
            ->post('/broadcasting/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => "private-orders.{$order->id}",
            ])
            ->assertForbidden();
    }
}
```

> See also: **laravel-testing** skill for general testing conventions and patterns.

## Summary of Conventions

| Convention | Rule |
|-----------|------|
| WebSocket server | Use Laravel Reverb (first-party) |
| Events | Implement `ShouldBroadcast` with queue support |
| Event naming | Use `broadcastAs()` with dot-notation |
| Payloads | Define `broadcastWith()` explicitly — never expose full models |
| Channels | Use private channels for user-specific data |
| Authorization | Always validate ownership in `routes/channels.php` |
| Frontend | Use Laravel Echo with typed event handlers |
| Cleanup | Always call `Echo.leave()` on component unmount |
| Whispers | Only for ephemeral UI state, never for data mutations |
| Notifications | Combine `database` + `broadcast` channels |
| Testing | Test channels, payloads, and authorization separately |
| Queue | Use a dedicated `broadcasts` queue for broadcast events |
