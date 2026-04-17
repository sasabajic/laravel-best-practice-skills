---
name: laravel-filament
description: Filament 3 admin panel best practices including panel configuration, resources, forms, tables, widgets, relation managers, actions, standalone components, multi-tenancy, and plugin development. Activates when working with Filament, admin panels, CRUD resources, or dashboard components.
---

# Filament 3 Best Practices

This skill covers Filament 3 — the TALL-stack admin panel framework for Laravel. All examples target **Filament v3.x** on **Laravel 10+** with **PHP 8.1+**.

> See also: **laravel-eloquent-database** skill for model conventions used alongside Filament resources.

> See also: **laravel-security** skill for authorization and policy patterns applied within panels.

---

## 1 · Panel Configuration

### Panel Provider Setup

Every Filament application starts with a **PanelProvider**. Keep configuration declarative and register plugins, pages, and resources explicitly.

```php
<?php

declare(strict_types=1);

namespace App\Providers\Filament;

use App\Filament\Pages\Dashboard;
use App\Filament\Resources\OrderResource;
use App\Filament\Resources\ProductResource;
use App\Filament\Resources\UserResource;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Filament\Widgets\AccountWidget;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Session\Middleware\StartSession;

final class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->login()
            ->colors([
                'primary' => Color::Indigo,
                'danger' => Color::Rose,
            ])
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\\Filament\\Pages')
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\\Filament\\Widgets')
            ->pages([
                Dashboard::class,
            ])
            ->widgets([
                AccountWidget::class,
            ])
            ->middleware([
                EncryptCookies::class,
                StartSession::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ])
            ->databaseNotifications()
            ->sidebarCollapsibleOnDesktop()
            ->maxContentWidth('full');
    }
}
```

### Panel Configuration Rules

- **One PanelProvider per panel** — register each in `config/app.php` providers array
- **Use `discoverResources()` / `discoverPages()` / `discoverWidgets()`** — auto-discovery keeps the provider clean
- **Set explicit `->id()` and `->path()`** — never rely on defaults for multi-panel apps
- **Enable `->databaseNotifications()`** only when you use the notifications package
- **Use `->sidebarCollapsibleOnDesktop()`** — improves UX on wide screens
- **Register global middleware** in the panel, not in `Kernel.php`
- **Use `->colors()`** with `Filament\Support\Colors\Color` enum — never hardcode hex values
- **Call `->brandLogo()`** and `->favicon()`** for production branding

### Navigation Customization

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use Filament\Resources\Resource;

final class OrderResource extends Resource
{
    protected static ?string $navigationIcon = 'heroicon-o-shopping-bag';

    protected static ?string $navigationGroup = 'Shop';

    protected static ?int $navigationSort = 1;

    protected static ?string $navigationLabel = 'Orders';

    public static function getNavigationBadge(): ?string
    {
        return (string) static::getModel()::where('status', 'pending')->count();
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return static::getModel()::where('status', 'pending')->count() > 10
            ? 'danger'
            : 'primary';
    }
}
```

### Navigation Rules

- **Group related resources** using `$navigationGroup` — e.g., `'Shop'`, `'Users'`, `'Settings'`
- **Set `$navigationSort`** to control ordering within groups
- **Use `heroicon-o-*` (outline)** icons for navigation — keep style consistent
- **Badge counts must be lightweight** — cache heavy queries or use a denormalized counter
- **Use `shouldRegisterNavigation(): bool`** to conditionally hide navigation items based on permissions

---

## 2 · Resources (CRUD)

### Resource Structure

```
app/Filament/Resources/
├── OrderResource.php
├── OrderResource/
│   ├── Pages/
│   │   ├── CreateOrder.php
│   │   ├── EditOrder.php
│   │   └── ListOrders.php
│   └── RelationManagers/
│       └── OrderItemsRelationManager.php
├── ProductResource.php
└── UserResource.php
```

### Resource Skeleton

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Filament\Resources\OrderResource\Pages;
use App\Filament\Resources\OrderResource\RelationManagers\OrderItemsRelationManager;
use App\Models\Order;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

final class OrderResource extends Resource
{
    protected static ?string $model = Order::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-bag';

    protected static ?string $navigationGroup = 'Shop';

    protected static ?string $recordTitleAttribute = 'number';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Order Details')
                    ->schema([
                        Forms\Components\Select::make('user_id')
                            ->relationship('user', 'name')
                            ->searchable()
                            ->preload()
                            ->required(),

                        Forms\Components\TextInput::make('number')
                            ->default(fn (): string => 'ORD-' . str_pad((string) random_int(1, 99999), 5, '0', STR_PAD_LEFT))
                            ->disabled()
                            ->dehydrated()
                            ->required()
                            ->maxLength(32)
                            ->unique(Order::class, 'number', ignoreRecord: true),

                        Forms\Components\Select::make('status')
                            ->options([
                                'pending' => 'Pending',
                                'processing' => 'Processing',
                                'shipped' => 'Shipped',
                                'delivered' => 'Delivered',
                                'cancelled' => 'Cancelled',
                            ])
                            ->default('pending')
                            ->required(),

                        Forms\Components\DateTimePicker::make('ordered_at')
                            ->default(now())
                            ->required(),
                    ])
                    ->columns(2),

                Forms\Components\Section::make('Totals')
                    ->schema([
                        Forms\Components\TextInput::make('subtotal')
                            ->numeric()
                            ->prefix('$')
                            ->required(),

                        Forms\Components\TextInput::make('total')
                            ->numeric()
                            ->prefix('$')
                            ->required(),
                    ])
                    ->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('number')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.name')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'pending' => 'warning',
                        'processing' => 'info',
                        'shipped' => 'primary',
                        'delivered' => 'success',
                        'cancelled' => 'danger',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('total')
                    ->money('usd')
                    ->sortable(),

                Tables\Columns\TextColumn::make('ordered_at')
                    ->dateTime()
                    ->sortable(),
            ])
            ->defaultSort('ordered_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'processing' => 'Processing',
                        'shipped' => 'Shipped',
                        'delivered' => 'Delivered',
                        'cancelled' => 'Cancelled',
                    ])
                    ->multiple(),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            OrderItemsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListOrders::route('/'),
            'create' => Pages\CreateOrder::route('/create'),
            'edit' => Pages\EditOrder::route('/{record}/edit'),
        ];
    }

    public static function getGloballySearchableAttributes(): array
    {
        return ['number', 'user.name'];
    }
}
```

### Resource Rules

- **Always set `$recordTitleAttribute`** — enables global search and improves select labels
- **Always set `$model`** — never rely on class name inference
- **Use `final class`** for resources — avoid inheritance chains between resources
- **Group form fields into `Section` components** — improves readability
- **Define `getGloballySearchableAttributes()`** for resources users will search frequently
- **Use relationship selects with `->searchable()->preload()`** — prevents loading all records at once
- **Separate form and table definitions** into the resource — never define them in page classes unless customizing per-page
- **Use `->unique(..., ignoreRecord: true)`** to prevent self-conflicts on edit

---

## 3 · Forms

### Field Types and Layout

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Forms\Set;

// Inside a resource or standalone form:
public static function form(Form $form): Form
{
    return $form
        ->schema([
            Forms\Components\Wizard::make([
                Forms\Components\Wizard\Step::make('Customer')
                    ->schema([
                        Forms\Components\Select::make('user_id')
                            ->relationship('user', 'name')
                            ->searchable()
                            ->preload()
                            ->createOptionForm([
                                Forms\Components\TextInput::make('name')
                                    ->required()
                                    ->maxLength(255),
                                Forms\Components\TextInput::make('email')
                                    ->email()
                                    ->required()
                                    ->maxLength(255),
                            ])
                            ->required(),
                    ]),

                Forms\Components\Wizard\Step::make('Products')
                    ->schema([
                        Forms\Components\Repeater::make('items')
                            ->relationship()
                            ->schema([
                                Forms\Components\Select::make('product_id')
                                    ->relationship('product', 'name')
                                    ->searchable()
                                    ->preload()
                                    ->required()
                                    ->reactive()
                                    ->afterStateUpdated(function (Set $set, ?string $state): void {
                                        if (! $state) {
                                            return;
                                        }

                                        $product = \App\Models\Product::find($state);
                                        $set('unit_price', $product?->price ?? 0);
                                    }),

                                Forms\Components\TextInput::make('quantity')
                                    ->numeric()
                                    ->default(1)
                                    ->minValue(1)
                                    ->required()
                                    ->reactive()
                                    ->afterStateUpdated(fn (Set $set, Get $get) => $set(
                                        'line_total',
                                        (float) $get('quantity') * (float) $get('unit_price'),
                                    )),

                                Forms\Components\TextInput::make('unit_price')
                                    ->numeric()
                                    ->prefix('$')
                                    ->disabled()
                                    ->dehydrated(),

                                Forms\Components\TextInput::make('line_total')
                                    ->numeric()
                                    ->prefix('$')
                                    ->disabled()
                                    ->dehydrated(),
                            ])
                            ->columns(4)
                            ->defaultItems(1)
                            ->addActionLabel('Add product')
                            ->reorderable()
                            ->collapsible(),
                    ]),

                Forms\Components\Wizard\Step::make('Notes')
                    ->schema([
                        Forms\Components\RichEditor::make('notes')
                            ->columnSpanFull()
                            ->toolbarButtons([
                                'bold',
                                'italic',
                                'bulletList',
                                'orderedList',
                                'link',
                            ]),
                    ]),
            ])
                ->columnSpanFull()
                ->skippable(),
        ]);
}
```

### Dependent Fields and Reactivity

```php
// GOOD — use Get/Set closures with reactive()
Forms\Components\Select::make('country_id')
    ->options(Country::pluck('name', 'id'))
    ->reactive()
    ->afterStateUpdated(fn (Set $set) => $set('state_id', null))
    ->required(),

Forms\Components\Select::make('state_id')
    ->options(fn (Get $get): array =>
        State::where('country_id', $get('country_id'))
            ->pluck('name', 'id')
            ->toArray()
    )
    ->disabled(fn (Get $get): bool => ! $get('country_id'))
    ->required(),

// BAD — querying inside label without scoping to parent
Forms\Components\Select::make('state_id')
    ->options(State::pluck('name', 'id'))  // Loads ALL states regardless of country
    ->required(),
```

### Conditional Visibility

```php
// GOOD — toggle fields based on other field values
Forms\Components\Select::make('shipping_method')
    ->options([
        'standard' => 'Standard',
        'express' => 'Express',
        'pickup' => 'Store Pickup',
    ])
    ->reactive()
    ->required(),

Forms\Components\TextInput::make('shipping_address')
    ->required()
    ->visible(fn (Get $get): bool => in_array($get('shipping_method'), ['standard', 'express'])),

Forms\Components\Select::make('pickup_location')
    ->options(PickupLocation::pluck('name', 'id'))
    ->required()
    ->visible(fn (Get $get): bool => $get('shipping_method') === 'pickup'),
```

### Custom Validation

```php
Forms\Components\TextInput::make('discount_percent')
    ->numeric()
    ->minValue(0)
    ->maxValue(100)
    ->suffix('%')
    ->rules([
        fn (): \Closure => function (string $attribute, mixed $value, \Closure $fail): void {
            if ($value > 50 && ! auth()->user()?->can('apply-high-discount')) {
                $fail('You are not authorized to apply discounts over 50%.');
            }
        },
    ]),
```

### Form Rules

- **Always add `->required()` or `->nullable()`** to every field — be explicit about requirements
- **Use `->reactive()`** only on fields that trigger updates — excessive reactivity causes unnecessary Livewire round-trips
- **Use `Get` and `Set` typed closures** — never reference `$livewire->data` directly
- **Use `->dehydrated()`** on disabled fields that must be saved — disabled fields are excluded from submission by default
- **Prefer `->relationship()`** on selects — Filament handles loading and saving automatically
- **Use `->searchable()->preload()`** on relationship selects with more than 20 records
- **Use `->createOptionForm()`** on selects to allow inline record creation
- **Wrap related fields in `Section`, `Fieldset`, or `Grid`** — never put more than 6 fields at the top level
- **Use `Repeater` with `->relationship()`** for HasMany inline editing
- **Limit `RichEditor` toolbar buttons** to what is actually needed — fewer options, cleaner content
- **Use `->columnSpanFull()`** for wide fields like text areas and rich editors

> See also: **laravel-security** skill for server-side validation — Filament form validation alone is not sufficient for API-accessible models.

---

## 4 · Tables

### Column Types and Formatting

```php
<?php

declare(strict_types=1);

use Filament\Tables;
use Filament\Tables\Table;

public static function table(Table $table): Table
{
    return $table
        ->columns([
            Tables\Columns\TextColumn::make('number')
                ->label('Order #')
                ->searchable()
                ->sortable()
                ->copyable()
                ->copyMessage('Order number copied'),

            Tables\Columns\TextColumn::make('user.name')
                ->label('Customer')
                ->searchable(['users.name', 'users.email'])
                ->sortable(),

            Tables\Columns\ImageColumn::make('user.avatar_url')
                ->label('Avatar')
                ->circular()
                ->defaultImageUrl(fn ($record): string =>
                    'https://ui-avatars.com/api/?name=' . urlencode($record->user->name)
                ),

            Tables\Columns\TextColumn::make('status')
                ->badge()
                ->color(fn (string $state): string => match ($state) {
                    'pending' => 'warning',
                    'processing' => 'info',
                    'shipped', 'delivered' => 'success',
                    'cancelled' => 'danger',
                    default => 'gray',
                })
                ->icon(fn (string $state): string => match ($state) {
                    'pending' => 'heroicon-m-clock',
                    'processing' => 'heroicon-m-arrow-path',
                    'shipped' => 'heroicon-m-truck',
                    'delivered' => 'heroicon-m-check-circle',
                    'cancelled' => 'heroicon-m-x-circle',
                    default => 'heroicon-m-question-mark-circle',
                }),

            Tables\Columns\TextColumn::make('total')
                ->money('usd')
                ->sortable()
                ->summarize(Tables\Columns\Summarizers\Sum::make()->money('usd')),

            Tables\Columns\TextColumn::make('items_count')
                ->counts('items')
                ->label('Items')
                ->sortable(),

            Tables\Columns\TextColumn::make('ordered_at')
                ->dateTime('M j, Y H:i')
                ->sortable()
                ->toggleable(isToggledHiddenByDefault: true),

            Tables\Columns\TextColumn::make('created_at')
                ->dateTime()
                ->sortable()
                ->toggleable(isToggledHiddenByDefault: true),
        ])
        ->defaultSort('ordered_at', 'desc');
}
```

### Filters

```php
->filters([
    Tables\Filters\SelectFilter::make('status')
        ->options([
            'pending' => 'Pending',
            'processing' => 'Processing',
            'shipped' => 'Shipped',
            'delivered' => 'Delivered',
            'cancelled' => 'Cancelled',
        ])
        ->multiple()
        ->preload(),

    Tables\Filters\Filter::make('ordered_at')
        ->form([
            Forms\Components\DatePicker::make('from'),
            Forms\Components\DatePicker::make('until'),
        ])
        ->query(function (\Illuminate\Database\Eloquent\Builder $query, array $data): \Illuminate\Database\Eloquent\Builder {
            return $query
                ->when($data['from'], fn ($q, $date) => $q->whereDate('ordered_at', '>=', $date))
                ->when($data['until'], fn ($q, $date) => $q->whereDate('ordered_at', '<=', $date));
        })
        ->indicateUsing(function (array $data): array {
            $indicators = [];

            if ($data['from'] ?? null) {
                $indicators[] = Tables\Filters\Indicator::make('From ' . \Carbon\Carbon::parse($data['from'])->toFormattedDateString())
                    ->removeField('from');
            }

            if ($data['until'] ?? null) {
                $indicators[] = Tables\Filters\Indicator::make('Until ' . \Carbon\Carbon::parse($data['until'])->toFormattedDateString())
                    ->removeField('until');
            }

            return $indicators;
        }),

    Tables\Filters\TernaryFilter::make('has_notes')
        ->queries(
            true: fn (\Illuminate\Database\Eloquent\Builder $query) => $query->whereNotNull('notes'),
            false: fn (\Illuminate\Database\Eloquent\Builder $query) => $query->whereNull('notes'),
        ),
])
->filtersFormColumns(3)
```

### Table Actions and Bulk Actions

```php
->actions([
    Tables\Actions\ActionGroup::make([
        Tables\Actions\ViewAction::make(),
        Tables\Actions\EditAction::make(),

        Tables\Actions\Action::make('ship')
            ->icon('heroicon-o-truck')
            ->color('success')
            ->requiresConfirmation()
            ->modalHeading('Ship Order')
            ->modalDescription('Are you sure you want to mark this order as shipped?')
            ->action(function (Order $record): void {
                $record->update(['status' => 'shipped']);
                \Filament\Notifications\Notification::make()
                    ->title('Order shipped')
                    ->success()
                    ->send();
            })
            ->visible(fn (Order $record): bool => $record->status === 'processing'),

        Tables\Actions\Action::make('download_invoice')
            ->icon('heroicon-o-document-arrow-down')
            ->url(fn (Order $record): string => route('orders.invoice', $record))
            ->openUrlInNewTab(),

        Tables\Actions\DeleteAction::make(),
    ]),
])
->bulkActions([
    Tables\Actions\BulkActionGroup::make([
        Tables\Actions\DeleteBulkAction::make(),

        Tables\Actions\BulkAction::make('mark_shipped')
            ->icon('heroicon-o-truck')
            ->requiresConfirmation()
            ->deselectRecordsAfterCompletion()
            ->action(fn (\Illuminate\Database\Eloquent\Collection $records) =>
                $records->each->update(['status' => 'shipped'])
            ),
    ]),
])
```

### Table Grouping

```php
->groups([
    Tables\Grouping\Group::make('status')
        ->label('Status')
        ->collapsible(),

    Tables\Grouping\Group::make('ordered_at')
        ->label('Order Date')
        ->date(),
])
->defaultGroup('status')
```

### Table Export

```php
<?php

declare(strict_types=1);

namespace App\Filament\Exports;

use App\Models\Order;
use Filament\Actions\Exports\ExportColumn;
use Filament\Actions\Exports\Exporter;
use Filament\Actions\Exports\Models\Export;

final class OrderExporter extends Exporter
{
    protected static ?string $model = Order::class;

    public static function getColumns(): array
    {
        return [
            ExportColumn::make('number'),
            ExportColumn::make('user.name')->label('Customer'),
            ExportColumn::make('status'),
            ExportColumn::make('total'),
            ExportColumn::make('ordered_at'),
        ];
    }

    public static function getCompletedNotificationBody(Export $export): string
    {
        $body = 'Your order export has completed. ' . number_format($export->successful_rows) . ' rows exported.';

        if ($failedRowsCount = $export->getFailedRowsCount()) {
            $body .= ' ' . number_format($failedRowsCount) . ' rows failed to export.';
        }

        return $body;
    }
}
```

Then in the table header:

```php
->headerActions([
    Tables\Actions\ExportAction::make()
        ->exporter(OrderExporter::class),
])
```

### Table Rules

- **Always add `->searchable()` and `->sortable()`** to columns users will query — do not add them to every column blindly
- **Use `->toggleable(isToggledHiddenByDefault: true)`** for low-priority columns like timestamps
- **Use `->badge()` with `->color()`** for status columns — match colors to meaning (danger = bad, success = good)
- **Wrap row actions in `ActionGroup`** when there are more than 2 actions — prevents table width bloat
- **Use `->deselectRecordsAfterCompletion()`** on bulk actions — avoids stale selection state
- **Always use `->requiresConfirmation()`** on destructive or irreversible actions
- **Use `->counts()` and `->summarize()`** instead of computed columns — they generate optimized SQL
- **Use `->indicateUsing()`** on custom filters — provides clear feedback about active filters
- **Use `->defaultSort()`** — never rely on database default ordering
- **Prefer `SelectFilter` with `->multiple()`** for enum-like columns
- **Use Exporter classes** for CSV/XLSX exports — never build manual download actions

---

## 5 · Relation Managers

### HasMany Relation Manager

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources\OrderResource\RelationManagers;

use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

final class OrderItemsRelationManager extends RelationManager
{
    protected static string $relationship = 'items';

    protected static ?string $title = 'Order Items';

    protected static ?string $recordTitleAttribute = 'product.name';

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Select::make('product_id')
                    ->relationship('product', 'name')
                    ->searchable()
                    ->preload()
                    ->required(),

                Forms\Components\TextInput::make('quantity')
                    ->numeric()
                    ->default(1)
                    ->minValue(1)
                    ->required(),

                Forms\Components\TextInput::make('unit_price')
                    ->numeric()
                    ->prefix('$')
                    ->required(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('product.name')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('quantity')
                    ->sortable(),

                Tables\Columns\TextColumn::make('unit_price')
                    ->money('usd')
                    ->sortable(),

                Tables\Columns\TextColumn::make('line_total')
                    ->money('usd')
                    ->state(fn ($record): float => $record->quantity * $record->unit_price),
            ])
            ->headerActions([
                Tables\Actions\CreateAction::make(),
                Tables\Actions\AttachAction::make()
                    ->preloadRecordSelect(),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DetachAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DetachBulkAction::make(),
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }
}
```

### Relation Manager Rules

- **Name the class `{RelatedModel}s{RelationManager}`** — e.g., `OrderItemsRelationManager`
- **Always set `$relationship`** to the Eloquent relationship method name
- **Set `$recordTitleAttribute`** for meaningful select labels
- **Use `AttachAction` / `DetachAction`** for BelongsToMany, `CreateAction` / `DeleteAction` for HasMany
- **Register all relation managers in `getRelations()`** on the parent resource

---

## 6 · Widgets

### Stats Overview Widget

```php
<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Order;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

final class OrderStatsWidget extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        return [
            Stat::make('Total Orders', Order::count())
                ->description('All time')
                ->descriptionIcon('heroicon-m-shopping-bag')
                ->chart([7, 3, 4, 5, 6, 3, 5])
                ->color('primary'),

            Stat::make('Revenue', '$' . number_format(Order::sum('total'), 2))
                ->description('7% increase')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->color('success'),

            Stat::make('Pending Orders', Order::where('status', 'pending')->count())
                ->description('Needs attention')
                ->descriptionIcon('heroicon-m-clock')
                ->color('warning'),
        ];
    }
}
```

### Chart Widget

```php
<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Order;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Carbon;

final class OrdersPerMonthChart extends ChartWidget
{
    protected static ?string $heading = 'Orders per Month';

    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    protected static ?string $maxHeight = '300px';

    protected function getData(): array
    {
        $data = Order::query()
            ->selectRaw('MONTH(ordered_at) as month, COUNT(*) as count')
            ->whereYear('ordered_at', now()->year)
            ->groupByRaw('MONTH(ordered_at)')
            ->orderByRaw('MONTH(ordered_at)')
            ->pluck('count', 'month')
            ->toArray();

        $months = collect(range(1, 12))->map(
            fn (int $month): string => Carbon::create(null, $month)->format('M'),
        );

        return [
            'datasets' => [
                [
                    'label' => 'Orders',
                    'data' => $months->keys()->map(fn (int $key): int => $data[$key + 1] ?? 0)->toArray(),
                    'backgroundColor' => 'rgba(99, 102, 241, 0.2)',
                    'borderColor' => 'rgb(99, 102, 241)',
                ],
            ],
            'labels' => $months->toArray(),
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}
```

### Widget Rules

- **Set `$sort`** to control widget ordering on the dashboard
- **Use `$columnSpan`** — `1`, `2`, or `'full'` to control layout
- **Set `$maxHeight`** on chart widgets — prevents oversized charts
- **Cache expensive queries** in `getStats()` — widgets reload on every page view
- **Register resource-specific widgets** via `getHeaderWidgets()` / `getFooterWidgets()` in page classes
- **Use `protected static ?string $pollingInterval = '30s'`** for real-time stats — set to `null` to disable polling

---

## 7 · Infolists (Read-Only Display)

### Infolist Setup

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use Filament\Infolists;
use Filament\Infolists\Infolist;

// Inside OrderResource:
public static function infolist(Infolist $infolist): Infolist
{
    return $infolist
        ->schema([
            Infolists\Components\Section::make('Order Information')
                ->schema([
                    Infolists\Components\TextEntry::make('number')
                        ->label('Order #')
                        ->copyable(),

                    Infolists\Components\TextEntry::make('user.name')
                        ->label('Customer'),

                    Infolists\Components\TextEntry::make('status')
                        ->badge()
                        ->color(fn (string $state): string => match ($state) {
                            'pending' => 'warning',
                            'processing' => 'info',
                            'shipped' => 'success',
                            'delivered' => 'success',
                            'cancelled' => 'danger',
                            default => 'gray',
                        }),

                    Infolists\Components\TextEntry::make('total')
                        ->money('usd'),

                    Infolists\Components\TextEntry::make('ordered_at')
                        ->dateTime(),

                    Infolists\Components\TextEntry::make('notes')
                        ->markdown()
                        ->columnSpanFull(),
                ])
                ->columns(3),

            Infolists\Components\Section::make('Items')
                ->schema([
                    Infolists\Components\RepeatableEntry::make('items')
                        ->schema([
                            Infolists\Components\TextEntry::make('product.name'),
                            Infolists\Components\TextEntry::make('quantity'),
                            Infolists\Components\TextEntry::make('unit_price')
                                ->money('usd'),
                        ])
                        ->columns(3),
                ]),
        ]);
}
```

Then add a ViewOrder page:

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources\OrderResource\Pages;

use App\Filament\Resources\OrderResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

final class ViewOrder extends ViewRecord
{
    protected static string $resource = OrderResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
```

Register the page in the resource:

```php
public static function getPages(): array
{
    return [
        'index' => Pages\ListOrders::route('/'),
        'create' => Pages\CreateOrder::route('/create'),
        'view' => Pages\ViewOrder::route('/{record}'),
        'edit' => Pages\EditOrder::route('/{record}/edit'),
    ];
}
```

### Infolist Rules

- **Use infolists for read-only views** — do not repurpose disabled forms as view pages
- **Mirror the form layout** with `Section` and `columns()` for visual consistency
- **Use `->badge()` and `->color()`** on status entries — match the table column styling
- **Use `RepeatableEntry`** for HasMany relations in view mode
- **Use `->copyable()`** on reference numbers, IDs, and URLs
- **Use `->markdown()` or `->html()`** for rich text entries

---

## 8 · Standalone Forms and Tables (Outside Panels)

### Standalone Form in a Livewire Component

```php
<?php

declare(strict_types=1);

namespace App\Livewire;

use App\Models\Order;
use Filament\Forms;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Livewire\Component;

final class CreateOrderForm extends Component implements HasForms
{
    use InteractsWithForms;

    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill();
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('number')
                    ->required()
                    ->maxLength(32),

                Forms\Components\Select::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'processing' => 'Processing',
                    ])
                    ->required(),
            ])
            ->statePath('data');
    }

    public function create(): void
    {
        $data = $this->form->getState();

        Order::create($data);

        Notification::make()
            ->title('Order created')
            ->success()
            ->send();

        $this->form->fill();
    }

    public function render(): \Illuminate\Contracts\View\View
    {
        return view('livewire.create-order-form');
    }
}
```

Blade template (`resources/views/livewire/create-order-form.blade.php`):

```blade
<div>
    <form wire:submit="create">
        {{ $this->form }}

        <x-filament::button type="submit" class="mt-4">
            Create Order
        </x-filament::button>
    </form>

    <x-filament-actions::modals />
</div>
```

### Standalone Table in a Livewire Component

```php
<?php

declare(strict_types=1);

namespace App\Livewire;

use App\Models\Order;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Tables;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Livewire\Component;

final class OrdersTable extends Component implements HasForms, HasTable
{
    use InteractsWithForms;
    use InteractsWithTable;

    protected function getTableQuery(): Builder
    {
        return Order::query()->with('user');
    }

    public function table(Table $table): Table
    {
        return $table
            ->query($this->getTableQuery())
            ->columns([
                Tables\Columns\TextColumn::make('number')->searchable(),
                Tables\Columns\TextColumn::make('user.name')->searchable(),
                Tables\Columns\TextColumn::make('total')->money('usd'),
            ])
            ->actions([
                Tables\Actions\Action::make('view')
                    ->url(fn (Order $record): string => route('orders.show', $record)),
            ]);
    }

    public function render(): \Illuminate\Contracts\View\View
    {
        return view('livewire.orders-table');
    }
}
```

### Standalone Rules

- **Always implement `HasForms`** — even standalone tables require it alongside `HasTable`
- **Always use both the interface AND the trait** — `HasForms` + `InteractsWithForms`, `HasTable` + `InteractsWithTable`
- **Set `->statePath('data')`** on standalone forms — stores form state in a `$data` property
- **Call `$this->form->fill()`** in `mount()` — initializes form state
- **Use `$this->form->getState()`** to retrieve validated data — never read `$this->data` directly
- **Include `<x-filament-actions::modals />`** in the Blade template if using any modal actions
- **Publish the Filament assets** with `php artisan filament:assets` when using standalone components

---

## 9 · Multi-Tenancy

### Tenant Configuration

```php
<?php

declare(strict_types=1);

namespace App\Providers\Filament;

use App\Models\Team;
use Filament\Panel;
use Filament\PanelProvider;

final class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->tenant(Team::class)
            ->tenantRegistration(\App\Filament\Pages\Tenancy\RegisterTeam::class)
            ->tenantProfile(\App\Filament\Pages\Tenancy\EditTeamProfile::class)
            ->tenantMiddleware([
                \Filament\Http\Middleware\IdentifyTenant::class,
            ])
            ->login();
    }
}
```

### Tenant Model

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Filament\Models\Contracts\HasTenants;
use Filament\Panel;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Collection;

final class User extends \Illuminate\Foundation\Auth\User implements HasTenants
{
    public function teams(): BelongsToMany
    {
        return $this->belongsToMany(Team::class);
    }

    public function getTenants(Panel $panel): array|Collection
    {
        return $this->teams;
    }

    public function canAccessTenant(Model $tenant): bool
    {
        return $this->teams()->whereKey($tenant)->exists();
    }
}
```

### Scoping Resources to Tenants

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

final class Order extends Model
{
    protected $fillable = [
        'team_id',
        'user_id',
        'number',
        'status',
        'total',
        'ordered_at',
    ];

    public function team(): BelongsTo
    {
        return $this->belongsTo(Team::class);
    }
}
```

Filament automatically scopes queries when the resource model has a `BelongsTo` relationship named after the tenant. For custom scoping:

```php
// In the resource class:
public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
{
    return parent::getEloquentQuery()->where('team_id', \Filament\Facades\Filament::getTenant()?->id);
}
```

### Multi-Tenancy Rules

- **User model must implement `HasTenants`** — requires `getTenants()` and `canAccessTenant()` methods
- **Tenant model must have a relationship to User** — typically BelongsToMany via a pivot table
- **Every tenant-scoped model needs a `BelongsTo` to the tenant model** — Filament uses this for automatic scoping
- **Override `getEloquentQuery()`** only when automatic tenant scoping is insufficient
- **Always register `IdentifyTenant` middleware** in the panel provider
- **Use `Filament::getTenant()`** to access the current tenant anywhere in Filament context
- **Test tenant isolation** — ensure users cannot access other tenants' records via URL manipulation

> See also: **laravel-security** skill for tenant data isolation and authorization best practices.

---

## 10 · Actions and Notifications

### Custom Page Action

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources\OrderResource\Pages;

use App\Filament\Resources\OrderResource;
use Filament\Actions;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;

final class EditOrder extends EditRecord
{
    protected static string $resource = OrderResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('approve')
                ->color('success')
                ->icon('heroicon-o-check-circle')
                ->requiresConfirmation()
                ->modalHeading('Approve Order')
                ->modalDescription('This will notify the customer and begin processing.')
                ->form([
                    \Filament\Forms\Components\Textarea::make('approval_notes')
                        ->label('Internal Notes')
                        ->maxLength(500),
                ])
                ->action(function (array $data): void {
                    $this->record->update([
                        'status' => 'processing',
                        'approved_at' => now(),
                        'approval_notes' => $data['approval_notes'] ?? null,
                    ]);

                    Notification::make()
                        ->title('Order Approved')
                        ->body("Order {$this->record->number} is now being processed.")
                        ->success()
                        ->sendToDatabase($this->record->user);

                    Notification::make()
                        ->title('Order approved successfully')
                        ->success()
                        ->send();
                })
                ->visible(fn (): bool => $this->record->status === 'pending'),

            Actions\DeleteAction::make(),
        ];
    }
}
```

### Notification Rules

- **Use `Notification::make()->send()`** for flash notifications — shown in the current session
- **Use `->sendToDatabase()`** for persistent notifications — requires `databaseNotifications()` on the panel
- **Always set `->title()` and `->success()` / `->danger()`** — provide clear user feedback
- **Add `->body()`** with context — include the record identifier in the message

---

## 11 · Plugins and Customization

### Creating a Plugin

```php
<?php

declare(strict_types=1);

namespace App\Filament\Plugins;

use Filament\Contracts\Plugin;
use Filament\Panel;

final class AuditLogPlugin implements Plugin
{
    public static function make(): static
    {
        return app(static::class);
    }

    public function getId(): string
    {
        return 'audit-log';
    }

    public function register(Panel $panel): void
    {
        $panel
            ->resources([
                \App\Filament\Resources\AuditLogResource::class,
            ])
            ->pages([
                \App\Filament\Pages\AuditDashboard::class,
            ]);
    }

    public function boot(Panel $panel): void
    {
        // Runtime setup — event listeners, middleware, etc.
    }
}
```

Register in the panel:

```php
->plugins([
    AuditLogPlugin::make(),
])
```

### Custom Theme

```php
// In PanelProvider:
->viteTheme('resources/css/filament/admin/theme.css')
```

```css
/* resources/css/filament/admin/theme.css */
@import '/vendor/filament/filament/resources/css/theme.css';

@config 'tailwind.config.js';

/* Custom overrides */
:root {
    --sidebar-width: 18rem;
}
```

### Plugin and Customization Rules

- **Implement `Filament\Contracts\Plugin`** — use `register()` for service container bindings, `boot()` for runtime setup
- **Use `->viteTheme()`** for custom CSS — never override Filament's core styles directly
- **Create a Tailwind config** that extends Filament's preset when customizing themes
- **Use `->renderHook()`** for injecting content at specific panel locations
- **Prefer existing Filament plugins** from the ecosystem before building custom solutions

---

## 12 · Filament + Livewire Integration

### Custom Livewire Component Inside a Resource Page

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources\OrderResource\Pages;

use App\Filament\Resources\OrderResource;
use Filament\Resources\Pages\ViewRecord;

final class ViewOrder extends ViewRecord
{
    protected static string $resource = OrderResource::class;

    protected function getFooterWidgets(): array
    {
        return [
            OrderResource\Widgets\OrderTimeline::class,
        ];
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources\OrderResource\Widgets;

use App\Models\Order;
use Filament\Widgets\Widget;
use Illuminate\Database\Eloquent\Model;

final class OrderTimeline extends Widget
{
    public ?Model $record = null;

    protected static string $view = 'filament.resources.order-resource.widgets.order-timeline';

    protected int|string|array $columnSpan = 'full';
}
```

### Livewire Integration Rules

- **Use Filament's `Widget` base class** for resource-level custom components — not raw Livewire components
- **Accept `$record`** as a public property on resource widgets — Filament injects it automatically
- **Use `getHeaderWidgets()` / `getFooterWidgets()`** in page classes — not `@livewire` directives in Blade
- **Dispatch Filament events** with `$this->dispatch('$refresh')` to reload Filament components
- **Use `Notification::make()->send()`** from Livewire components — works outside panels if the Filament notification Blade component is included

---

## 13 · Testing Filament Resources

### Testing with Livewire and Pest

```php
<?php

declare(strict_types=1);

use App\Filament\Resources\OrderResource;
use App\Filament\Resources\OrderResource\Pages\CreateOrder;
use App\Filament\Resources\OrderResource\Pages\EditOrder;
use App\Filament\Resources\OrderResource\Pages\ListOrders;
use App\Models\Order;
use App\Models\User;

use function Pest\Livewire\livewire;

beforeEach(function (): void {
    $this->actingAs(User::factory()->create());
});

it('can list orders', function (): void {
    $orders = Order::factory()->count(3)->create();

    livewire(ListOrders::class)
        ->assertCanSeeTableRecords($orders)
        ->assertCountTableRecords(3);
});

it('can create an order', function (): void {
    $user = User::factory()->create();

    livewire(CreateOrder::class)
        ->fillForm([
            'user_id' => $user->id,
            'number' => 'ORD-00001',
            'status' => 'pending',
            'subtotal' => 100.00,
            'total' => 110.00,
            'ordered_at' => now(),
        ])
        ->call('create')
        ->assertHasNoFormErrors();

    $this->assertDatabaseHas('orders', [
        'number' => 'ORD-00001',
        'status' => 'pending',
    ]);
});

it('can edit an order', function (): void {
    $order = Order::factory()->create();

    livewire(EditOrder::class, ['record' => $order->getRouteKey()])
        ->fillForm([
            'status' => 'processing',
        ])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($order->refresh()->status)->toBe('processing');
});

it('can filter orders by status', function (): void {
    $pending = Order::factory()->create(['status' => 'pending']);
    $shipped = Order::factory()->create(['status' => 'shipped']);

    livewire(ListOrders::class)
        ->filterTable('status', 'pending')
        ->assertCanSeeTableRecords([$pending])
        ->assertCanNotSeeTableRecords([$shipped]);
});

it('can sort orders by total', function (): void {
    $cheap = Order::factory()->create(['total' => 10]);
    $expensive = Order::factory()->create(['total' => 1000]);

    livewire(ListOrders::class)
        ->sortTable('total', 'desc')
        ->assertCanSeeTableRecords([$expensive, $cheap], inOrder: true);
});

it('can search orders by number', function (): void {
    $target = Order::factory()->create(['number' => 'ORD-99999']);
    $other = Order::factory()->create(['number' => 'ORD-00001']);

    livewire(ListOrders::class)
        ->searchTable('ORD-99999')
        ->assertCanSeeTableRecords([$target])
        ->assertCanNotSeeTableRecords([$other]);
});

it('validates required fields on create', function (): void {
    livewire(CreateOrder::class)
        ->fillForm([
            'user_id' => null,
            'number' => '',
        ])
        ->call('create')
        ->assertHasFormErrors([
            'user_id' => 'required',
            'number' => 'required',
        ]);
});
```

### Testing Rules

- **Always call `actingAs()`** before Filament page tests — panels require authentication
- **Use `livewire()` helper** with the page class, not the resource class
- **Pass `['record' => $model->getRouteKey()]`** for edit/view page tests
- **Use `assertCanSeeTableRecords()` / `assertCanNotSeeTableRecords()`** for table testing
- **Use `fillForm()` + `call('create')` / `call('save')`** for form submissions
- **Test filters with `filterTable()`**, sorts with `sortTable()`, search with `searchTable()`
- **Test authorization** — verify users without permission get 403 on resource pages

> See also: **laravel-testing** skill for general testing patterns and conventions.

---

## 14 · File Organization and Naming Conventions

| What | Convention | Example |
|------|-----------|---------|
| Resource | singular model name + `Resource` | `OrderResource` |
| Resource directory | matches resource name | `OrderResource/` |
| List page | `List` + plural model | `ListOrders` |
| Create page | `Create` + singular model | `CreateOrder` |
| Edit page | `Edit` + singular model | `EditOrder` |
| View page | `View` + singular model | `ViewOrder` |
| Relation manager | plural related model + `RelationManager` | `OrderItemsRelationManager` |
| Widget | descriptive name + `Widget` | `OrderStatsWidget` |
| Exporter | singular model + `Exporter` | `OrderExporter` |
| Plugin | descriptive name + `Plugin` | `AuditLogPlugin` |
| Panel provider | panel name + `PanelProvider` | `AdminPanelProvider` |

### Directory Structure

```
app/
├── Filament/
│   ├── Exports/
│   │   └── OrderExporter.php
│   ├── Pages/
│   │   ├── Dashboard.php
│   │   └── Tenancy/
│   │       ├── EditTeamProfile.php
│   │       └── RegisterTeam.php
│   ├── Plugins/
│   │   └── AuditLogPlugin.php
│   ├── Resources/
│   │   ├── OrderResource.php
│   │   ├── OrderResource/
│   │   │   ├── Pages/
│   │   │   │   ├── CreateOrder.php
│   │   │   │   ├── EditOrder.php
│   │   │   │   ├── ListOrders.php
│   │   │   │   └── ViewOrder.php
│   │   │   ├── RelationManagers/
│   │   │   │   └── OrderItemsRelationManager.php
│   │   │   └── Widgets/
│   │   │       └── OrderTimeline.php
│   │   ├── ProductResource.php
│   │   └── UserResource.php
│   └── Widgets/
│       ├── OrderStatsWidget.php
│       └── OrdersPerMonthChart.php
```

### General Rules

- **Follow Filament's generated structure** — use `php artisan make:filament-resource` as the starting point
- **Keep form and table definitions in the resource** — only override in page classes when page-specific behavior is needed
- **Use `final class`** on all Filament classes — resources, pages, widgets, relation managers
- **Use `declare(strict_types=1)`** in every PHP file
- **Type all return types** — `Form`, `Table`, `Infolist`, `array`, `string`, `bool`
- **Use PHP 8.1+ features** — enums, named arguments, match expressions, readonly properties
- **Prefer Filament's built-in features** over custom Livewire logic — forms, tables, actions, notifications
- **Apply Laravel policies** with `$model::policy()` — Filament respects `viewAny`, `create`, `update`, `delete` policy methods automatically
- **Run `php artisan filament:upgrade`** after updating Filament — ensures assets and config are in sync
