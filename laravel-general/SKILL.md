````skill
---
name: laravel-general
description: Core Laravel development principles, conventions, project structure, and philosophy. Activates for any Laravel-related coding task including creating controllers, models, routes, middleware, and general PHP development within a Laravel project.
---

# Laravel General Best Practices

You are an expert Laravel developer. Follow these principles and conventions in ALL Laravel code you write, review, or modify.

## Project Onboarding — First Steps When Entering a Laravel Project

**IMPORTANT:** When you first open, analyze, or start working on a Laravel project, ALWAYS perform these steps before any other work:

### Step 1: Check AI Memory (FIRST — BEFORE ANYTHING ELSE)

Look for `.ai/memory.md` in the project root:

- **If it exists:** Read it immediately. Check for unfinished work in the `## Work In Progress` section. If there's an active task, inform the user and ask whether to resume or start something new.
- **If it doesn't exist:** Create it from the template in the `ai-memory` skill. Analyze the project to populate the Project Identity section. Add `.ai/` to `.gitignore`.

> This is powered by the **ai-memory** skill. See it for the full template and update rules.

### Step 2: Check Laravel Version

Immediately check the current Laravel version:

```bash
php artisan --version
# or check composer.json
composer show laravel/framework | Select-String "versions"
```

Compare with the **latest stable Laravel release** (currently Laravel 12.x). If the project is NOT on the latest major version:

1. **Inform the user** of the current version and the latest available version
2. **Recommend upgrading** with a brief summary of benefits (security fixes, performance, new features)
3. **Offer to assist** with the upgrade process:
   - Review the official [Laravel Upgrade Guide](https://laravel.com/docs/12.x/upgrade)
   - Identify breaking changes that affect the project
   - Create a step-by-step upgrade plan
   - Run `composer update` with appropriate version constraints

```bash
# Check current version
php artisan --version

# Update to latest
composer require laravel/framework:^12.0
```

If the project is already on the latest version, confirm it and move on.

### Step 3: Install Laravel Boost (MCP Integration)

Check if **Laravel Boost** is installed. If NOT, **strongly recommend installing it**:

```bash
composer show laravel/boost 2>$null
```

If not installed, suggest:

```bash
composer require laravel/boost --dev
```

**Why Laravel Boost is essential:**
- Provides a **Model Context Protocol (MCP)** server that connects GitHub Copilot directly to the Laravel project
- Gives the AI deep understanding of the project: models, routes, database schema, config, relationships
- Enables much more accurate and context-aware code generation
- Allows querying the project structure, running artisan commands, and understanding relationships between components
- Dramatically improves AI assistance quality — the AI can "see" the actual project state

After installation, inform the user to configure MCP in their VS Code settings (`.vscode/mcp.json`):

```json
{
    "servers": {
        "laravel": {
            "type": "stdio",
            "command": "php",
            "args": ["artisan", "boost:mcp"]
        }
    }
}
```

> **Always mention:** "Installing Laravel Boost with MCP allows me to directly understand your project structure — models, routes, database schema, and more — so I can give you much better, project-specific assistance."

### Step 4: Project Analysis

After memory check, version check, and Boost setup, proceed with standard project analysis:

1. Review `composer.json` for dependencies and PHP version
2. Check the database structure (migrations or schema)
3. Review the project structure and identify patterns used
4. Note any deviations from Laravel conventions
5. Suggest improvements based on the skills in this collection

## Core Philosophy

1. **Follow Laravel conventions** — Don't fight the framework. Use built-in features before reaching for third-party packages or custom solutions.
2. **Fat models, skinny controllers** — Business logic belongs in models, services, or actions — NOT in controllers.
3. **DRY (Don't Repeat Yourself)** — Extract reusable logic into traits, services, helpers, or base classes.
4. **Convention over configuration** — Use Laravel's default naming, folder structure, and patterns unless there's a compelling reason not to.
5. **Use the latest Laravel features** — Always prefer modern Laravel syntax and features (e.g., Enums, typed properties, match expressions, named arguments).

## Project Structure

Always follow this standard Laravel project structure with the following additions:

```
app/
├── Actions/              # Single-purpose action classes
├── Console/
│   └── Commands/
├── DTOs/                 # Data Transfer Objects
├── Enums/                # PHP 8.1+ Enums
├── Events/
├── Exceptions/
├── Http/
│   ├── Controllers/
│   ├── Middleware/
│   ├── Requests/         # Form Request classes (validation)
│   └── Resources/        # API Resources
├── Jobs/
├── Listeners/
├── Mail/
├── Models/
├── Notifications/
├── Observers/
├── Policies/
├── Providers/
├── Rules/                # Custom validation rules
├── Services/             # Business logic service classes
├── Traits/
└── View/
    └── Components/       # Blade view components
```

## General Rules

### Use Strict Types

Always declare strict types at the top of every PHP file:

```php
<?php

declare(strict_types=1);
```

### Type Everything

- Always use return types on methods
- Always use typed parameters
- Always use typed properties
- Use union types when necessary (`string|int`)
- Use nullable types with `?` prefix when a value can be null
- Use `void` return type when a method doesn't return anything

```php
// GOOD
public function findUser(int $id): ?User
{
    return User::find($id);
}

// BAD — no types
public function findUser($id)
{
    return User::find($id);
}
```

### Use PHP 8.1+ Features

- **Enums** instead of constants for fixed sets of values
- **Readonly properties** for immutable data
- **Named arguments** for clarity when calling functions with many parameters
- **Match expressions** instead of switch statements
- **Fiber** for async when appropriate
- **Constructor property promotion**
- **First-class callable syntax** `$this->method(...)`
- **Intersection types** when needed
- **`never` return type** for methods that always throw

### Controllers

- Keep controllers thin — 5 methods max (index, show, store, update, destroy)
- Use **single-action controllers** (`__invoke`) when a controller has only one method
- Always use **Form Requests** for validation — never validate in controllers
- Always use **API Resources** for response transformation
- Use **route model binding** instead of manual model fetching
- Group related functionality into **resource controllers**

```php
// GOOD — thin controller with dependency injection
class UserController extends Controller
{
    public function __construct(
        private readonly UserService $userService,
    ) {}

    public function store(StoreUserRequest $request): JsonResponse
    {
        $user = $this->userService->create($request->validated());

        return UserResource::make($user)
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }
}
```

### Routing

- Use **resource routes** when possible: `Route::resource('users', UserController::class)`
- Use **route groups** with common middleware and prefixes
- Use **route names** for all routes: `->name('users.store')`
- Use **route model binding** for all model parameters
- Prefer **API resource routes** for API endpoints: `Route::apiResource()`
- Keep route files organized — split into separate files for web, API, admin, etc.

### Configuration

- Never call `env()` outside of config files — always use `config()` helper
- Create custom config files for application-specific settings
- Use `.env` for environment-specific values only

```php
// GOOD
config('app.timezone')

// BAD — never use env() outside config files
env('APP_TIMEZONE')
```

### Error Handling

- Use custom exception classes for domain-specific errors
- Always handle exceptions gracefully — never show raw exceptions to users
- Use Laravel's exception handler for global error handling
- Return appropriate HTTP status codes
- Log errors with context

```php
class InsufficientBalanceException extends DomainException
{
    public function __construct(
        public readonly float $balance,
        public readonly float $amount,
    ) {
        parent::__construct("Insufficient balance: {$balance}, required: {$amount}");
    }
}
```

### Naming Conventions Quick Reference

| What | Convention | Example |
|------|-----------|---------|
| Controller | singular, PascalCase, suffix `Controller` | `UserController` |
| Model | singular, PascalCase | `User`, `BlogPost` |
| Migration | snake_case, descriptive | `create_users_table` |
| Method | camelCase, verb first | `getActiveUsers()` |
| Variable | camelCase | `$activeUsers` |
| Route named | dot notation, lowercase | `users.store` |
| Config key | snake_case | `app.timezone` |
| Trait | adjective or PascalCase | `HasFactory`, `Searchable` |
| Interface | PascalCase, suffix `Interface` or adjective | `PaymentGatewayInterface` |
| Enum | singular PascalCase, cases PascalCase | `UserStatus::Active` |
| Event | past tense PascalCase | `OrderPlaced` |
| Listener | PascalCase, descriptive | `SendOrderNotification` |
| Job | PascalCase, descriptive | `ProcessPayment` |
| Mail | PascalCase | `WelcomeEmail` |
| Notification | PascalCase | `InvoicePaid` |
| Form Request | PascalCase, prefix verb | `StoreUserRequest`, `UpdateUserRequest` |
| Resource | singular PascalCase, suffix `Resource` | `UserResource` |
| Seeder | PascalCase, suffix `Seeder` | `UserSeeder` |
| Factory | PascalCase, suffix `Factory` | `UserFactory` |
| Policy | singular PascalCase, suffix `Policy` | `UserPolicy` |
| Rule | PascalCase | `ValidPhoneNumber` |
| Service | PascalCase, suffix `Service` | `PaymentService` |
| Action | PascalCase, verb prefix | `CreateUser`, `SendInvoice` |
| DTO | PascalCase, suffix `Data` or `DTO` | `UserData`, `CreateUserDTO` |

### Use Laravel Helpers and Features

- Use `str()` / `Str::` for string manipulation
- Use `collect()` / `Collection` methods instead of raw array functions
- Use `Carbon` for all date/time operations
- Use `Arr::` helper for array operations
- Use `data_get()` / `data_set()` for nested array access
- Use `optional()` or null safe operator `?->` to avoid null checks
- Use `blank()` / `filled()` for checking empty values
- Use `rescue()` for graceful error handling in non-critical operations

### Comments and Documentation

- Write **docblocks** for public methods that aren't self-documenting
- Use `@throws` annotation when a method can throw exceptions
- Don't comment obvious code — write self-documenting code instead
- Use `// TODO:` and `// FIXME:` for things that need attention
- Write clear commit messages following conventional commits

````
