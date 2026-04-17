---
name: laravel-notifications
description: Laravel notification best practices including mail, database, broadcast, SMS, and Slack notification channels, notification classes, on-demand notifications, queueable notifications, and notification preferences. Activates when working with notifications, alerts, user messaging, or notification channels.
---

# Laravel Notification Best Practices

Follow these conventions when building notifications in Laravel. Notifications provide a unified API for delivering messages across multiple channels — mail, database, broadcast, SMS, and Slack.

## Notification Class Convention

### Naming & Structure

Name notifications after the event they represent, using past tense. Place them in `app/Notifications/` grouped by domain.

```
app/Notifications/
├── Orders/
│   ├── OrderConfirmed.php
│   ├── OrderShipped.php
│   └── OrderRefunded.php
├── Auth/
│   ├── PasswordResetRequested.php
│   └── TwoFactorEnabled.php
└── Billing/
    ├── PaymentFailed.php
    └── InvoiceGenerated.php
```

### Generating Notifications

```bash
php artisan make:notification Orders/OrderShipped
```

### Class Structure

```php
<?php

declare(strict_types=1);

namespace App\Notifications\Orders;

use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

// GOOD — final class, ShouldQueue, typed properties and returns
final class OrderShipped extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly Order $order,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail', 'database'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject("Order #{$this->order->number} Has Shipped")
            ->greeting("Hello {$notifiable->name}!")
            ->line("Your order #{$this->order->number} is on its way.")
            ->action('Track Order', url("/orders/{$this->order->id}/tracking"))
            ->line('Thank you for your purchase!');
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return [
            'order_id' => $this->order->id,
            'order_number' => $this->order->number,
            'message' => "Order #{$this->order->number} has shipped.",
        ];
    }
}
```

```php
// BAD — no ShouldQueue, vague naming, no types
class SendNotification extends Notification
{
    public $data; // untyped, vague property name

    public function __construct($data)
    {
        $this->data = $data;
    }

    public function via($notifiable)
    {
        return ['mail'];
    }

    public function toMail($notifiable)
    {
        return (new MailMessage)->line($this->data['message']);
    }
}
```

### Sending Notifications

```php
// Via the Notifiable trait on a model
$user->notify(new OrderShipped($order));

// Via the Notification facade (supports multiple notifiables)
use Illuminate\Support\Facades\Notification;

Notification::send($users, new OrderShipped($order));
```

## Mail Notifications

### MailMessage API

```php
public function toMail(object $notifiable): MailMessage
{
    return (new MailMessage)
        ->from('shipping@example.com', 'Shipping Team')
        ->subject("Order #{$this->order->number} Confirmed")
        ->greeting('Hello!')
        ->line('Your order has been confirmed and is being processed.')
        ->lineIf($this->order->is_priority, '🚀 This is a priority order!')
        ->action('View Order', url("/orders/{$this->order->id}"))
        ->line('Thank you for shopping with us.')
        ->salutation('Best regards, The Team');
}
```

### Markdown Mail Notifications

```bash
php artisan make:notification InvoiceGenerated --markdown=mail.invoices.generated
```

```php
public function toMail(object $notifiable): MailMessage
{
    return (new MailMessage)
        ->subject('Your Invoice')
        ->markdown('mail.invoices.generated', [
            'invoice' => $this->invoice,
            'url' => url("/invoices/{$this->invoice->id}"),
        ]);
}
```

```blade
{{-- resources/views/mail/invoices/generated.blade.php --}}
<x-mail::message>
# Invoice #{{ $invoice->number }}

Your invoice for **{{ $invoice->formatted_total }}** is ready.

<x-mail::table>
| Item       | Qty | Price   |
|:-----------|:---:|--------:|
@foreach ($invoice->items as $item)
| {{ $item->name }} | {{ $item->quantity }} | {{ $item->formatted_price }} |
@endforeach
| **Total**  |     | **{{ $invoice->formatted_total }}** |
</x-mail::table>

<x-mail::button :url="$url">
Download Invoice
</x-mail::button>

Thanks,<br>
{{ config('app.name') }}
</x-mail::message>
```

### Customizing the Mail Theme

```bash
php artisan vendor:publish --tag=laravel-mail
```

This publishes the mail components to `resources/views/vendor/mail/` for full customization.

## Database Notifications

Database notifications store notification data in a `notifications` table, ideal for in-app notification feeds.

### Setup

```bash
php artisan notifications:table
php artisan migrate
```

### Storing Notifications

```php
// GOOD — structured data with consistent keys
/** @return array<string, mixed> */
public function toArray(object $notifiable): array
{
    return [
        'type' => 'order_shipped',
        'order_id' => $this->order->id,
        'order_number' => $this->order->number,
        'message' => "Order #{$this->order->number} has shipped.",
        'url' => "/orders/{$this->order->id}/tracking",
    ];
}

// BAD — unstructured, inconsistent data
public function toArray($notifiable)
{
    return [
        'text' => 'something happened',
    ];
}
```

### Reading & Marking Notifications

```php
// Get all notifications
$notifications = $user->notifications;

// Get unread notifications only
$unread = $user->unreadNotifications;

// Mark a single notification as read
$notification->markAsRead();

// Mark all as read
$user->unreadNotifications->markAsRead();

// In a controller — mark as read and redirect
final class NotificationController extends Controller
{
    public function read(string $id): RedirectResponse
    {
        $notification = auth()->user()
            ->notifications()
            ->findOrFail($id);

        $notification->markAsRead();

        return redirect($notification->data['url'] ?? '/dashboard');
    }
}
```

### Pruning Old Notifications

```php
// app/Console/Kernel.php or routes/console.php
use Illuminate\Notifications\DatabaseNotification;

Schedule::command('model:prune', ['--model' => DatabaseNotification::class])->daily();
```

> **See also:** `laravel-performance` skill for queue and scheduling optimization.

## Broadcast Notifications

Broadcast notifications push real-time updates to the frontend via WebSockets. Combine with Laravel Echo for reactive UIs.

### Notification Class

```php
<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\BroadcastMessage;
use Illuminate\Notifications\Notification;

final class OrderStatusChanged extends Notification implements ShouldQueue, ShouldBroadcast
{
    use Queueable;

    public function __construct(
        private readonly Order $order,
        private readonly string $status,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['broadcast', 'database'];
    }

    public function toBroadcast(object $notifiable): BroadcastMessage
    {
        return new BroadcastMessage([
            'order_id' => $this->order->id,
            'status' => $this->status,
            'message' => "Order #{$this->order->number} is now {$this->status}.",
        ]);
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return [
            'order_id' => $this->order->id,
            'status' => $this->status,
            'message' => "Order #{$this->order->number} is now {$this->status}.",
        ];
    }
}
```

### Listening with Echo (Frontend)

```javascript
// Listen on the authenticated user's private notification channel
Echo.private(`App.Models.User.${userId}`)
    .notification((notification) => {
        console.log(notification.type);
        console.log(notification.order_id);
    });
```

> **See also:** `laravel-real-time` skill for full Reverb/Echo setup and channel authorization.

## SMS Notifications (Vonage)

### Installation

```bash
composer require laravel/vonage-notification-channel
```

### Notification Class

```php
<?php

declare(strict_types=1);

namespace App\Notifications\Auth;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\VonageMessage;
use Illuminate\Notifications\Notification;

final class VerificationCodeSent extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly string $code,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['vonage'];
    }

    public function toVonage(object $notifiable): VonageMessage
    {
        return (new VonageMessage)
            ->content("Your verification code is: {$this->code}. It expires in 10 minutes.")
            ->from('MyApp');
    }
}
```

### Notifiable Model Setup

```php
// Implement routeNotificationForVonage on the model
public function routeNotificationForVonage(): string
{
    return $this->phone_number;
}
```

## Slack Notifications

### Installation

```bash
composer require laravel/slack-notification-channel
```

### Notification Class

```php
<?php

declare(strict_types=1);

namespace App\Notifications\Billing;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\SlackMessage;
use Illuminate\Notifications\Notification;

final class PaymentFailed extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly string $customerName,
        private readonly string $amount,
        private readonly string $reason,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['slack'];
    }

    public function toSlack(object $notifiable): SlackMessage
    {
        return (new SlackMessage)
            ->error()
            ->headerBlock('Payment Failed')
            ->sectionBlock(function ($block) {
                $block->text("Payment of {$this->amount} from {$this->customerName} failed.");
            })
            ->contextBlock(function ($block) {
                $block->text("Reason: {$this->reason}");
            });
    }
}
```

### Routing Slack Notifications

```php
// On the notifiable model
public function routeNotificationForSlack(): string
{
    return $this->slack_webhook_url;
}
```

## On-Demand Notifications

Send notifications to recipients who are not stored as models — useful for invitations, guest checkouts, or admin alerts.

```php
use Illuminate\Support\Facades\Notification;

// GOOD — on-demand notification to an email address
Notification::route('mail', 'guest@example.com')
    ->route('slack', 'https://hooks.slack.com/services/...')
    ->notify(new OrderConfirmed($order));

// On-demand with named recipient
Notification::route('mail', ['guest@example.com' => 'Guest User'])
    ->notify(new OrderConfirmed($order));
```

## Queueable Notifications

Always queue notifications that involve external services (mail, SMS, Slack) to avoid blocking HTTP requests.

```php
// GOOD — implements ShouldQueue with queue/retry configuration
final class OrderShipped extends Notification implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;
    public int $backoff = 60;

    public function __construct(
        private readonly Order $order,
    ) {
        $this->onQueue('notifications');
        $this->afterCommit();
    }

    // ...
}
```

```php
// BAD — synchronous notification blocks the request
final class OrderShipped extends Notification // Missing ShouldQueue
{
    public function __construct(
        private readonly Order $order,
    ) {}

    public function via(object $notifiable): array
    {
        return ['mail']; // Mail sent synchronously — slow!
    }

    // ...
}
```

### Conditional Sending

```php
// Prevent sending if conditions are no longer met
public function shouldSend(object $notifiable, string $channel): bool
{
    return $this->order->status === 'shipped';
}
```

> **See also:** `laravel-performance` skill for queue configuration, worker tuning, and retry strategies.

## Notification Preferences & Unsubscribe Pattern

### Channel Preferences

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

final class NotificationPreference extends Model
{
    protected $fillable = [
        'user_id',
        'notification_type',
        'channels',
    ];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'channels' => 'array',
        ];
    }
}
```

### Dynamic Channel Selection

```php
/** @return array<int, string> */
public function via(object $notifiable): array
{
    // GOOD — respect user preferences
    $preference = $notifiable->notificationPreferences()
        ->where('notification_type', static::class)
        ->first();

    if ($preference) {
        return $preference->channels;
    }

    // Defaults when no preference is set
    return ['mail', 'database'];
}
```

### Unsubscribe via Signed URL

```php
// Generate signed unsubscribe link in the mail notification
public function toMail(object $notifiable): MailMessage
{
    $unsubscribeUrl = URL::signedRoute('notifications.unsubscribe', [
        'user' => $notifiable->id,
        'type' => static::class,
    ]);

    return (new MailMessage)
        ->subject('Order Update')
        ->line('Your order has been updated.')
        ->action('View Order', url("/orders/{$this->order->id}"))
        ->line("[Unsubscribe from these notifications]({$unsubscribeUrl})");
}
```

```php
// Controller to handle unsubscribe
Route::get('/notifications/unsubscribe', function (Request $request) {
    if (! $request->hasValidSignature()) {
        abort(403);
    }

    NotificationPreference::updateOrCreate(
        [
            'user_id' => $request->user,
            'notification_type' => $request->type,
        ],
        ['channels' => []],
    );

    return view('notifications.unsubscribed');
})->name('notifications.unsubscribe');
```

## Custom Notification Channels

Build custom channels for services not included out of the box.

```php
<?php

declare(strict_types=1);

namespace App\Channels;

use Illuminate\Notifications\Notification;

final class TelegramChannel
{
    public function __construct(
        private readonly TelegramClient $client,
    ) {}

    public function send(object $notifiable, Notification $notification): void
    {
        $message = $notification->toTelegram($notifiable);

        $chatId = $notifiable->routeNotificationFor('telegram');

        if (! $chatId) {
            return;
        }

        $this->client->sendMessage($chatId, $message['text']);
    }
}
```

### Registering the Custom Channel

```php
/** @return array<int, string|class-string> */
public function via(object $notifiable): array
{
    return ['mail', TelegramChannel::class];
}

/** @return array<string, string> */
public function toTelegram(object $notifiable): array
{
    return [
        'text' => "Order #{$this->order->number} has shipped!",
    ];
}
```

## Testing Notifications

Use `Notification::fake()` to intercept all notifications in tests and assert they were sent correctly.

### Basic Assertions

```php
use App\Notifications\Orders\OrderShipped;
use Illuminate\Support\Facades\Notification;

test('notification is sent when order ships', function () {
    Notification::fake();

    $user = User::factory()->create();
    $order = Order::factory()->for($user)->create();

    // Trigger the action that sends the notification
    $order->markAsShipped();

    Notification::assertSentTo($user, OrderShipped::class);
});

test('notification is not sent for cancelled orders', function () {
    Notification::fake();

    $user = User::factory()->create();
    $order = Order::factory()->for($user)->cancelled()->create();

    $order->markAsShipped();

    Notification::assertNotSentTo($user, OrderShipped::class);
});
```

### Asserting Notification Content

```php
test('shipped notification contains correct order data', function () {
    Notification::fake();

    $user = User::factory()->create();
    $order = Order::factory()->for($user)->create(['number' => 'ORD-123']);

    $order->markAsShipped();

    Notification::assertSentTo($user, OrderShipped::class, function ($notification, $channels) {
        expect($channels)->toContain('mail', 'database');

        $mail = $notification->toMail($notification);
        expect($mail->subject)->toContain('ORD-123');

        $data = $notification->toArray($notification);
        expect($data)
            ->toHaveKey('order_number', 'ORD-123')
            ->toHaveKey('order_id');

        return true;
    });
});
```

### Asserting Notification Count

```php
test('admin receives exactly one daily digest notification', function () {
    Notification::fake();

    $admin = User::factory()->admin()->create();

    (new SendDailyDigest)->handle();

    Notification::assertSentToTimes($admin, DailyDigest::class, 1);
});

test('no notifications are sent at all', function () {
    Notification::fake();

    // perform action...

    Notification::assertNothingSent();
});
```

> **See also:** `laravel-testing` skill for comprehensive Pest PHP testing patterns, fakes, and assertions.

## Notification Grouping & Throttling

### Debounce / Throttle with Rate Limiting

```php
<?php

declare(strict_types=1);

namespace App\Notifications\Billing;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Facades\RateLimiter;

final class PaymentRetryFailed extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly string $invoiceId,
    ) {}

    public function shouldSend(object $notifiable, string $channel): bool
    {
        // GOOD — throttle to 1 notification per hour per user
        $key = "notification:payment-retry:{$notifiable->id}";

        return RateLimiter::attempt($key, maxAttempts: 1, callback: fn () => true, decaySeconds: 3600);
    }

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Payment Retry Failed')
            ->line('We were unable to process your payment. Please update your payment method.');
    }
}
```

### Digest / Batch Notifications

Instead of sending many individual notifications, aggregate them into a single digest.

```php
<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Collection;

final class ActivityDigest extends Notification implements ShouldQueue
{
    use Queueable;

    /** @param Collection<int, array<string, mixed>> $activities */
    public function __construct(
        private readonly Collection $activities,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $message = (new MailMessage)
            ->subject("You have {$this->activities->count()} new updates")
            ->greeting("Hi {$notifiable->name},");

        $this->activities->each(function (array $activity) use ($message) {
            $message->line("• {$activity['description']}");
        });

        return $message->action('View All Activity', url('/activity'));
    }
}
```

```php
// GOOD — scheduled command to send digests instead of individual notifications
// routes/console.php
Schedule::call(function () {
    User::whereHas('unreadActivities')
        ->with('unreadActivities')
        ->chunk(100, function ($users) {
            $users->each(function ($user) {
                $user->notify(new ActivityDigest($user->unreadActivities));
                $user->unreadActivities()->update(['notified' => true]);
            });
        });
})->dailyAt('08:00');
```

```php
// BAD — sending a notification for every single activity
foreach ($activities as $activity) {
    $user->notify(new SingleActivityNotification($activity)); // spammy!
}
```

## Quick Reference

| Channel     | Method          | Package Required                          |
|-------------|-----------------|-------------------------------------------|
| Mail        | `toMail()`      | Built-in                                  |
| Database    | `toArray()`     | Built-in (run `notifications:table`)      |
| Broadcast   | `toBroadcast()` | Built-in (requires Reverb/Pusher)         |
| SMS (Vonage)| `toVonage()`    | `laravel/vonage-notification-channel`     |
| Slack       | `toSlack()`     | `laravel/slack-notification-channel`      |
| Custom      | `toX()`         | Implement custom channel class            |

## Key Principles

1. **Always queue** notifications that touch external services (`implements ShouldQueue`).
2. **Use `afterCommit()`** to ensure notifications are sent only after database transactions commit.
3. **Respect user preferences** — let users choose which channels they receive notifications on.
4. **Throttle and batch** — avoid notification fatigue by rate-limiting and sending digests.
5. **Test with `Notification::fake()`** — assert notifications are sent to the right users on the right channels.
6. **Use `shouldSend()`** — guard against stale or invalid notifications at dispatch time.
7. **Structure `toArray()` data consistently** — include an `id`, `message`, and `url` for database notifications.
8. **Prune old database notifications** — schedule `model:prune` to keep the notifications table manageable.
