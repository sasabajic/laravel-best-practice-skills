---
name: laravel-scheduling
description: Laravel task scheduling and Artisan console command best practices including schedule definition, frequency options, overlapping prevention, maintenance mode, output handling, console command conventions, and cron setup. Activates when working with scheduling, cron jobs, artisan commands, or background tasks.
---

# Laravel Task Scheduling & Console Commands Best Practices

Follow these conventions for building Artisan console commands and defining task schedules in Laravel applications. All examples target **Laravel 10+** with notes where behavior differs across versions.

## Console Command Conventions

### Command Structure

```php
<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\OrderService;
use Illuminate\Console\Command;

// GOOD — final class, typed return, descriptive signature
final class PruneStaleOrders extends Command
{
    protected $signature = 'orders:prune
        {--days=30 : Number of days after which orders are considered stale}
        {--dry-run : Show what would be deleted without actually deleting}';

    protected $description = 'Remove stale incomplete orders older than the given threshold';

    public function handle(OrderService $orderService): int
    {
        $days = (int) $this->option('days');
        $dryRun = (bool) $this->option('dry-run');

        $count = $orderService->pruneStaleOrders($days, $dryRun);

        if ($dryRun) {
            $this->info("Dry run: {$count} orders would be pruned.");

            return self::SUCCESS;
        }

        $this->info("Successfully pruned {$count} stale orders.");

        return self::SUCCESS;
    }
}
```

```php
// BAD — vague naming, no types, business logic inline
class DoStuff extends Command
{
    protected $signature = 'do:stuff';

    public function handle()
    {
        // Inline database queries and business logic...
        DB::table('orders')->where('created_at', '<', now()->subDays(30))->delete();
        $this->line('Done');
    }
}
```

### Naming Conventions

Use `domain:action` format for command signatures:

| Pattern | Example | When to use |
|---------|---------|-------------|
| `domain:action` | `orders:prune` | Standard CRUD-like operations |
| `domain:action-modifier` | `users:export-csv` | Specific variants of an action |
| `domain:sync` | `inventory:sync` | External system synchronization |
| `app:setup` | `app:install` | Application-level setup commands |

### Command Arguments and Options

```php
<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;

final class SendReport extends Command
{
    // Required argument, optional argument with default, options with values and flags
    protected $signature = 'reports:send
        {type : The report type (daily, weekly, monthly)}
        {recipient? : Optional email recipient}
        {--format=pdf : Output format (pdf, csv, xlsx)}
        {--queue : Dispatch to queue instead of sending synchronously}
        {--cc=* : Additional CC recipients}';

    protected $description = 'Generate and send a report';

    public function handle(): int
    {
        $type = $this->argument('type');
        $recipient = $this->argument('recipient') ?? config('reports.default_recipient');
        $format = $this->option('format');
        $shouldQueue = (bool) $this->option('queue');
        $ccRecipients = $this->option('cc');

        // Validate argument values
        if (! in_array($type, ['daily', 'weekly', 'monthly'], true)) {
            $this->error("Invalid report type: {$type}");

            return self::FAILURE;
        }

        $this->info("Generating {$type} report in {$format} format...");

        return self::SUCCESS;
    }
}
```

## Command Output

### Structured Output Methods

```php
<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

final class AuditUsers extends Command
{
    protected $signature = 'users:audit';

    protected $description = 'Audit user accounts and report status';

    public function handle(): int
    {
        // Informational output
        $this->info('Starting user audit...');

        // Warning
        $this->warn('This may take a while for large datasets.');

        // Table output for structured data
        $users = User::query()
            ->select(['id', 'name', 'email', 'last_login_at'])
            ->where('last_login_at', '<', now()->subMonths(6))
            ->limit(50)
            ->get();

        $this->table(
            ['ID', 'Name', 'Email', 'Last Login'],
            $users->map(fn (User $user): array => [
                $user->id,
                $user->name,
                $user->email,
                $user->last_login_at?->diffForHumans() ?? 'Never',
            ])->toArray(),
        );

        // Progress bar for long operations
        $allUsers = User::query()->cursor();
        $bar = $this->output->createProgressBar(User::count());
        $bar->start();

        foreach ($allUsers as $user) {
            // Process each user...
            $bar->advance();
        }

        $bar->finish();
        $this->newLine(2);

        // Confirmation prompt
        if ($this->confirm('Deactivate inactive users?', false)) {
            $this->info('Deactivating...');
        }

        $this->info('Audit complete.');

        return self::SUCCESS;
    }
}
```

## Schedule Definition

### Laravel 11+ (routes/console.php)

In **Laravel 11+**, schedule definitions go in `routes/console.php` using the `Schedule` facade:

```php
<?php

// routes/console.php

use Illuminate\Support\Facades\Schedule;

// Closure-based command
Schedule::command('orders:prune --days=60')
    ->daily()
    ->at('02:00')
    ->withoutOverlapping()
    ->onOneServer()
    ->emailOutputOnFailure('ops@example.com');

Schedule::command('reports:send daily')
    ->dailyAt('08:00')
    ->environments(['production'])
    ->onOneServer();

Schedule::command('telescope:prune --hours=48')
    ->daily()
    ->at('03:00');

Schedule::command('queue:prune-batches --hours=48')
    ->daily()
    ->at('03:30');

// Job-based scheduling
Schedule::job(new \App\Jobs\AggregateAnalytics())
    ->hourly()
    ->withoutOverlapping(30); // Lock expires after 30 minutes

// Shell command
Schedule::exec('node /home/forge/scripts/deploy.js')
    ->weekly()
    ->sundays()
    ->at('04:00')
    ->onOneServer();
```

### Laravel 10 (Console/Kernel.php)

In **Laravel 10**, define the schedule in the `Kernel` class:

```php
<?php

declare(strict_types=1);

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

final class Kernel extends ConsoleKernel
{
    protected function schedule(Schedule $schedule): void
    {
        $schedule->command('orders:prune --days=60')
            ->daily()
            ->at('02:00')
            ->withoutOverlapping()
            ->onOneServer()
            ->emailOutputOnFailure('ops@example.com');

        $schedule->command('reports:send daily')
            ->dailyAt('08:00')
            ->environments(['production']);
    }

    protected function commands(): void
    {
        $this->load(__DIR__ . '/Commands');
    }
}
```

## Frequency Options

### Common Schedules

```php
// Time-based frequencies
Schedule::command('task:run')->everyMinute();
Schedule::command('task:run')->everyFiveMinutes();
Schedule::command('task:run')->everyTenMinutes();
Schedule::command('task:run')->everyFifteenMinutes();
Schedule::command('task:run')->everyThirtyMinutes();
Schedule::command('task:run')->hourly();
Schedule::command('task:run')->hourlyAt(15);          // At :15 past each hour
Schedule::command('task:run')->daily();                // At 00:00
Schedule::command('task:run')->dailyAt('13:00');       // At 1 PM
Schedule::command('task:run')->twiceDaily(1, 13);      // At 1:00 & 13:00
Schedule::command('task:run')->weekly();
Schedule::command('task:run')->weeklyOn(1, '08:00');   // Monday at 8:00 AM
Schedule::command('task:run')->monthly();
Schedule::command('task:run')->monthlyOn(1, '00:00');  // 1st of month
Schedule::command('task:run')->quarterly();
Schedule::command('task:run')->yearly();

// Cron expression (minute hour day month weekday)
Schedule::command('task:run')->cron('0 */4 * * *');    // Every 4 hours

// Day constraints
Schedule::command('task:run')->weekdays();
Schedule::command('task:run')->weekends();
Schedule::command('task:run')->sundays();
Schedule::command('task:run')->mondays();
// ... tuesdays(), wednesdays(), thursdays(), fridays(), saturdays()

// Conditional scheduling
Schedule::command('task:run')
    ->hourly()
    ->when(fn (): bool => app()->environment('production'));

Schedule::command('task:run')
    ->hourly()
    ->skip(fn (): bool => app()->isDownForMaintenance());

// Between time windows
Schedule::command('task:run')
    ->hourly()
    ->between('08:00', '17:00');  // Only during business hours

Schedule::command('task:run')
    ->hourly()
    ->unlessBetween('23:00', '05:00');  // Not during off-hours
```

## Overlapping Prevention

```php
// GOOD — prevent overlapping runs
Schedule::command('analytics:aggregate')
    ->hourly()
    ->withoutOverlapping();

// GOOD — custom lock expiration (minutes) for long-running tasks
Schedule::command('data:import')
    ->daily()
    ->withoutOverlapping(120);  // Lock expires after 120 minutes

// BAD — no overlapping protection on a long-running command
Schedule::command('data:import')
    ->everyMinute();
```

> **Note:** `withoutOverlapping()` uses the cache driver to create mutex locks. Ensure your cache driver supports atomic locks (Redis recommended). The default lock expiration is 24 hours.

## Running on One Server

For **multi-server deployments**, use `onOneServer()` to ensure a scheduled task runs on only one server:

```php
// GOOD — runs on a single server only (requires Redis or Memcached cache driver)
Schedule::command('reports:send daily')
    ->dailyAt('08:00')
    ->onOneServer()
    ->withoutOverlapping();

Schedule::job(new \App\Jobs\CleanupTempFiles())
    ->hourly()
    ->onOneServer();
```

> **Requirement:** `onOneServer()` requires a centralized cache driver (Redis or Memcached). It will NOT work with the `file` or `array` cache driver. See **laravel-deployment** skill for Redis setup.

## Maintenance Mode Behavior

By default, scheduled tasks do **not** run when the application is in maintenance mode.

```php
// Force a task to run even during maintenance mode
Schedule::command('payments:process-pending')
    ->everyFiveMinutes()
    ->evenInMaintenanceMode();

// GOOD — critical payment processing should not stop during deploys
Schedule::command('queue:work --stop-when-empty')
    ->everyMinute()
    ->evenInMaintenanceMode()
    ->withoutOverlapping();
```

## Schedule Output and Logging

```php
// Send output to a file
Schedule::command('reports:generate')
    ->daily()
    ->sendOutputTo(storage_path('logs/reports.log'));

// Append output to a file (keeps history)
Schedule::command('reports:generate')
    ->daily()
    ->appendOutputTo(storage_path('logs/reports.log'));

// Email output (requires mail to be configured)
Schedule::command('reports:generate')
    ->daily()
    ->emailOutputTo('admin@example.com');

// Email output only on failure
Schedule::command('data:sync')
    ->hourly()
    ->emailOutputOnFailure('ops@example.com');
```

## Background vs Foreground Execution

```php
// GOOD — run in background (non-blocking, allows parallel execution)
Schedule::command('analytics:process')
    ->hourly()
    ->runInBackground();

Schedule::command('cache:warm')
    ->hourly()
    ->runInBackground();

// Default (foreground) — tasks run sequentially, one at a time
Schedule::command('quick:task')
    ->everyMinute();
```

> **Tip:** Use `runInBackground()` for long-running tasks so they don't block subsequent scheduled tasks. Without it, the scheduler waits for each task to complete before starting the next.

## Lifecycle Hooks

```php
Schedule::command('data:import')
    ->daily()
    ->before(function (): void {
        // Runs before the task starts
        logger()->info('Starting data import...');
    })
    ->after(function (): void {
        // Runs after the task completes
        logger()->info('Data import finished.');
    })
    ->onSuccess(function (): void {
        // Runs only if the task succeeded (exit code 0)
        Cache::put('last_import_success', now());
    })
    ->onFailure(function (): void {
        // Runs only if the task failed (non-zero exit code)
        Notification::route('slack', config('services.slack.ops_webhook'))
            ->notify(new \App\Notifications\ScheduledTaskFailed('data:import'));
    });
```

## Calling Commands from Code

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Artisan;

final class AdminController extends Controller
{
    // GOOD — call Artisan command programmatically
    public function clearCache(): JsonResponse
    {
        Artisan::call('cache:clear');

        return response()->json([
            'message' => 'Cache cleared',
            'output' => Artisan::output(),
        ]);
    }

    // GOOD — queue a command for background execution
    public function generateReport(): JsonResponse
    {
        Artisan::queue('reports:send daily --format=pdf');

        return response()->json(['message' => 'Report generation queued']);
    }
}
```

```php
// Call from within another command
final class DeployCommand extends Command
{
    protected $signature = 'app:deploy';

    public function handle(): int
    {
        $this->call('migrate', ['--force' => true]);
        $this->call('config:cache');
        $this->call('route:cache');
        $this->call('view:cache');
        $this->call('event:cache');

        $this->info('Deployment tasks complete.');

        return self::SUCCESS;
    }
}
```

## Schedule Monitoring

### Health Check Ping

```php
// Ping a URL after successful completion (dead man's switch)
Schedule::command('data:sync')
    ->hourly()
    ->pingOnSuccess('https://health.example.com/check/data-sync')
    ->pingOnFailure('https://health.example.com/alert/data-sync');

// Ping before and after
Schedule::command('data:sync')
    ->hourly()
    ->pingBefore('https://health.example.com/start/data-sync')
    ->thenPing('https://health.example.com/end/data-sync');
```

### Failure Notifications

```php
<?php

declare(strict_types=1);

// routes/console.php (Laravel 11+) or in Kernel (Laravel 10)

use Illuminate\Support\Facades\Schedule;
use App\Notifications\ScheduledTaskFailed;
use Illuminate\Support\Facades\Notification;

Schedule::command('payments:process')
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->onOneServer()
    ->onFailure(function (): void {
        Notification::route('mail', 'ops@example.com')
            ->route('slack', config('services.slack.ops_webhook'))
            ->notify(new ScheduledTaskFailed(
                command: 'payments:process',
                failedAt: now(),
            ));
    });
```

> See **laravel-performance** skill for queue and job management patterns that complement scheduled tasks.

## Cron Setup for Production

### System Crontab Entry

Add a **single** cron entry on your production server — Laravel's scheduler handles the rest:

```bash
# Run the Laravel scheduler every minute
* * * * * cd /path-to-your-project && php artisan schedule:run >> /dev/null 2>&1
```

### With a Specific User

```bash
# As the www-data user (common for web servers)
* * * * * www-data cd /var/www/html && php artisan schedule:run >> /dev/null 2>&1
```

### Docker / Container Environments

```dockerfile
# In a supervisor config or entrypoint script
# Option 1: Dedicated scheduler container
CMD ["php", "artisan", "schedule:work"]
```

```ini
# Option 2: Supervisor config for scheduler alongside other processes
[program:scheduler]
process_name=%(program_name)s
command=php /var/www/html/artisan schedule:work
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/www/html/storage/logs/scheduler.log
```

> **`schedule:work`** (Laravel 8+) runs the scheduler in the foreground, checking every minute — ideal for Docker/containerized environments where cron is unavailable. See **laravel-deployment** skill for Docker and supervisor configuration.

### Verifying the Schedule

```bash
# List all scheduled tasks and their next run time
php artisan schedule:list

# Test run the scheduler immediately
php artisan schedule:test

# Run the scheduler once (useful for debugging)
php artisan schedule:run
```

## Testing Commands and Schedules

### Testing Commands with Pest

```php
<?php

use function Pest\Laravel\artisan;

describe('PruneStaleOrders', function () {
    it('prunes orders older than the given days', function () {
        // Arrange
        $oldOrder = Order::factory()->create([
            'status' => 'incomplete',
            'created_at' => now()->subDays(31),
        ]);
        $recentOrder = Order::factory()->create([
            'status' => 'incomplete',
            'created_at' => now()->subDays(5),
        ]);

        // Act & Assert
        artisan('orders:prune --days=30')
            ->expectsOutput('Successfully pruned 1 stale orders.')
            ->assertSuccessful();

        expect($oldOrder->fresh())->toBeNull();
        expect($recentOrder->fresh())->not->toBeNull();
    });

    it('shows count in dry-run mode without deleting', function () {
        Order::factory()->count(3)->create([
            'status' => 'incomplete',
            'created_at' => now()->subDays(31),
        ]);

        artisan('orders:prune --days=30 --dry-run')
            ->expectsOutput('Dry run: 3 orders would be pruned.')
            ->assertSuccessful();

        expect(Order::count())->toBe(3);
    });

    it('returns failure for invalid input', function () {
        artisan('reports:send invalid-type')
            ->assertFailed();
    });
});
```

### Testing Command Interactions

```php
<?php

use function Pest\Laravel\artisan;

it('asks for confirmation before deactivating users', function () {
    artisan('users:audit')
        ->expectsConfirmation('Deactivate inactive users?', 'yes')
        ->assertSuccessful();
});

it('can prompt for missing arguments', function () {
    artisan('reports:send')
        ->expectsQuestion('What type of report?', 'daily')
        ->assertSuccessful();
});
```

### Testing Scheduled Tasks

```php
<?php

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Schedule as ScheduleFacade;

// Laravel 11+ — test that a command is scheduled
it('schedules the order pruning daily', function () {
    // Laravel 11+: use Schedule facade to inspect
    $schedule = app(Schedule::class);
    $events = collect($schedule->events());

    $pruneEvent = $events->first(
        fn ($event) => str_contains($event->command, 'orders:prune')
    );

    expect($pruneEvent)->not->toBeNull();
    expect($pruneEvent->expression)->toBe('0 2 * * *'); // daily at 02:00
});

// Verify scheduled task constraints
it('runs order pruning only on production', function () {
    $schedule = app(Schedule::class);
    $events = collect($schedule->events());

    $pruneEvent = $events->first(
        fn ($event) => str_contains($event->command, 'orders:prune')
    );

    expect($pruneEvent->withoutOverlapping)->toBeTrue();
});
```

> See **laravel-testing** skill for full testing strategies including Pest configuration, database setup, and mocking patterns.

## Best Practices Summary

### DO

- **Use `final` classes** and `declare(strict_types=1)` in all commands
- **Return exit codes** — `self::SUCCESS` (0), `self::FAILURE` (1), `self::INVALID` (2)
- **Inject dependencies** via the `handle()` method signature (auto-resolved by the container)
- **Use `withoutOverlapping()`** on any task that takes more than a few seconds
- **Use `onOneServer()`** in multi-server deployments with a centralized cache driver
- **Use `runInBackground()`** for long-running tasks to avoid blocking the scheduler
- **Add `onFailure()` hooks or pings** for critical tasks (health monitoring)
- **Use `environments()`** to restrict tasks to specific environments
- **Log output** with `appendOutputTo()` or `sendOutputTo()` for audit trails
- **Test commands** with `artisan()` helper and `expectsOutput()` / `assertSuccessful()`

### DON'T

- **Don't put business logic directly in commands** — delegate to services or actions
- **Don't schedule resource-heavy tasks without overlapping prevention**
- **Don't use the `file` cache driver with `onOneServer()`** — use Redis or Memcached
- **Don't forget `--force` on `migrate`** when calling from a command in production
- **Don't run the scheduler more than once per minute** — it's designed for per-minute execution
- **Don't ignore exit codes** — always return `self::SUCCESS` or `self::FAILURE`

## Cross-References

- **laravel-performance** — Queue and job management, caching strategies for scheduled task results
- **laravel-deployment** — Docker supervisor config, cron setup, zero-downtime deployment considerations
- **laravel-testing** — Full testing patterns with Pest, database testing, and mocking
