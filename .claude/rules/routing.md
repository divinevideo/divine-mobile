# Routing

Use [GoRouter](https://pub.dev/packages/go_router) for declarative navigation with deep linking support.

---

## Route Configuration

### Use Sub-Routes
Structure routes logically, not flat:

```
✅ Good                    ❌ Bad
/                          /
/flutter                   /flutter
/flutter/news              /flutter-news
/flutter/chat              /flutter-chat
/android                   /android
/android/news              /android-news
```

Sub-routes ensure proper back navigation and URL readability.

### Use Hyphens in URLs
For multi-word paths:

```
✅ /user/update-address
❌ /user/update_address
❌ /user/updateAddress
```

---

## Type-Safe Routes

Use `@TypedGoRoute` for type safety:

```dart
@TypedGoRoute<CategoriesPageRoute>(
  name: 'categories',
  path: '/categories',
)
@immutable
class CategoriesPageRoute extends GoRouteData {
  const CategoriesPageRoute({
    this.size,
    this.color,
  });

  final String? size;
  final String? color;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return CategoriesPage(size: size, color: color);
  }
}

// Navigation
const CategoriesPageRoute(size: 'small', color: 'blue').go(context);
```

---

## Navigation Methods

### Prefer `go` Over `push`

| Method | Use When |
|--------|----------|
| `go` | Standard navigation (updates URL, manages back stack) |
| `push` | Expecting data back from route (dialogs, forms) |

```dart
// Standard navigation
context.go('/categories');
CategoriesPageRoute().go(context);

// When expecting return value
final result = await context.push<String>('/dialog');
```

### Prefer Name Over Path
Names survive path refactoring:

```dart
// Good - uses route name
context.goNamed('flutterNews');

// Bad - hardcoded path can break
context.go('/flutter-news');
```

### Use Extension Methods

```dart
// Good
context.goNamed('flutterNews');

// Bad
GoRouter.of(context).goNamed('flutterNews');
```

---

## Parameters

### Path Parameters
For identifying specific resources:

```dart
@TypedGoRoute<ArticlePageRoute>(
  name: 'article',
  path: 'article/:id',
)
@immutable
class ArticlePageRoute extends GoRouteData {
  const ArticlePageRoute({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ArticlePage(id: id);
  }
}

// Navigation
ArticlePageRoute(id: 'abc123').go(context);
// URL: /article/abc123
```

### Query Parameters
For filtering or sorting:

```dart
@TypedGoRoute<ArticlesPageRoute>(
  name: 'articles',
  path: '/articles',
)
@immutable
class ArticlesPageRoute extends GoRouteData {
  const ArticlesPageRoute({this.date, this.category});

  final String? date;
  final String? category;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ArticlesPage(date: date, category: category);
  }
}

// Navigation
ArticlesPageRoute(date: '07162024', category: 'all').go(context);
// URL: /articles?date=07162024&category=all
```

### Avoid Extra Parameter
Don't use `extra` for passing objects - breaks deep linking and web.

In this repo `extra` is a **warm-start cache only**: every route resolves from
path parameters, query parameters and repositories, and no route builder may
dead-end because `extra` was absent (#3335). Read it through `extraAs<T>` /
`extraValue<T>` from `mobile/lib/router/routes/route_extras.dart` — `extra` can
arrive as `null`, or as decoded JSON (a plain `Map<String, dynamic>`) rather
than the type that was passed, so a raw cast crashes the builder. Within one
session the router keeps typed objects when it re-reads its own route state,
through `RouteExtraCodec` (#9292); nothing carries them across a cold start or
a link. The per-route inventory of what each hint saves, and what a URL-only
entry falls back to, lives in
[`mobile/docs/DEEP_LINK_URL_REFERENCE.md`](../../mobile/docs/DEEP_LINK_URL_REFERENCE.md#route-state-and-extra).

```dart
// Bad - breaks deep linking
@TypedGoRoute<ArticlePageRoute>(
  name: 'article',
  path: 'article',
)
class ArticlePageRoute extends GoRouteData {
  const ArticlePageRoute({required this.article});
  final Article article;  // Object in extra - bad!
}

// Good - pass ID, fetch in page
@TypedGoRoute<ArticlePageRoute>(
  name: 'article',
  path: 'article/:id',
)
class ArticlePageRoute extends GoRouteData {
  const ArticlePageRoute({required this.id});
  final String id;  // ID can be in URL

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ArticlePage(id: id);  // Page fetches article
  }
}
```

---

## Redirects

### Global Redirects
For authentication:

```dart
GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final status = context.read<AppBloc>().state.status;
    if (status == AppStatus.unauthenticated) {
      return SignInPageRoute().location;
    }
    return null;  // No redirect
  },
  routes: $appRoutes,
);
```

### Route-Level Redirects
For specific route protection:

```dart
@TypedGoRoute<PremiumPageRoute>(
  name: 'premium',
  path: '/premium',
  routes: [
    TypedGoRoute<PremiumShowsPageRoute>(
      name: 'premiumShows',
      path: 'shows',
    ),
  ],
)
@immutable
class PremiumPageRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const PremiumPage();
  }

  @override
  String? redirect(BuildContext context, GoRouterState state) {
    final status = context.read<AppBloc>().state.user.status;
    if (status != UserStatus.premium) {
      return RestrictedPageRoute().location;
    }
    return null;
  }
}
```

**Note:** Parent redirects execute first, so one redirect on a parent can protect all sub-routes.

---

## Nested Routes Example

```dart
@TypedGoRoute<TechnologyPageRoute>(
  name: 'technology',
  path: '/technology',
  routes: [
    TypedGoRoute<FlutterPageRoute>(
      name: 'flutter',
      path: 'flutter',
      routes: [
        TypedGoRoute<FlutterNewsPageRoute>(
          name: 'flutterNews',
          path: 'news',
        ),
      ],
    ),
  ],
)
```

Results in:
- `/technology`
- `/technology/flutter`
- `/technology/flutter/news`

Each level supports proper back navigation.
