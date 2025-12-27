+++
date = '2025-12-27T12:35:14+08:00'
draft = false
title = 'When Loops Become Math: How Functional Thinking Changed My C++'
toc = true
+++

Last week, I was staring at two pieces of code a friend had sent me, asking
which one I preferred. They looked like this:

```cpp
// Version A
double calculate_mean(const vector<double>& data) {
    double sum = 0.0;
    for (const auto& x : data) {
        sum += x;
    }
    return sum / data.size();
}

// Version B
double calculate_stddev(const vector<double>& data) {
    double sum = 0.0;
    double mean = calculate_mean(data);
    for (const auto& x : data) {
        sum += (x - mean) * (x - mean);
    }
    return sqrt(sum / data.size());
}
```

I looked at them for a solid five seconds before it hit me: these two loops were
fundamentally the same mathematical pattern! But in the code, that pattern was
buried under `for` loops and accumulation variables.

## Seeing with Math Eyes

In math, we'd write these calculations as:

$$
\text{mean} = \frac{1}{n} \sum_{i=1}^n x_i
$$

$$
\text{stddev} = \sqrt{\frac{1}{n} \sum_{i=1}^n (x_i - \mu)^2}
$$

See that $\sum$ symbol? That's our abstraction point. In functional programming, this is called a **fold** (or reduce), defined as:

$$
\text{fold}(f, z, [x_1, x_2, ..., x_n]) = f(f(f(z, x_1), x_2), ..., x_n)
$$

Looking at my code with this new perspective:

```cpp
template<typename T, typename BinaryOp>
T fold(const vector<T>& vec, T init, BinaryOp op) {
    T result = init;
    for (const auto& x : vec) {
        result = op(result, x);
    }
    return result;
}
```

Now both calculations become:

```cpp
double mean = fold(data, 0.0, plus<double>{}) / data.size();

double variance = fold(data, 0.0, [mean](double acc, double x) {
    return acc + (x - mean) * (x - mean);
}) / data.size();
```

## The Real Breakthrough: Seeing Deeper Patterns

I started noticing this pattern everywhere. Take this convex hull algorithm I'd
written:

```cpp
vector<Point> find_convex_hull(const vector<Point>& points) {
    vector<Point> hull;
    for (size_t i = 0; i < points.size(); ++i) {
        for (size_t j = 0; j < points.size(); ++j) {
            if (i == j) continue;
            bool all_on_same_side = true;
            for (size_t k = 0; k < points.size(); ++k) {
                if (k == i || k == j) continue;
                if (!is_on_same_side(points[i], points[j], points[k])) {
                    all_on_same_side = false;
                    break;
                }
            }
            if (all_on_same_side) {
                hull.push_back(points[i]);
                hull.push_back(points[j]);
            }
        }
    }
    return remove_duplicates(hull);
}
```

Three nested loops! But with functional thinking, I saw **predicate logic**:

> A point pair (i,j) belongs to the convex hull boundary if and only if all
> other points are on the same side of the line segment (i,j).

Mathematically:
$$
(i,j) \in \text{hull} \iff \forall k \neq i,j : \text{same\_side}(i,j,k)
$$

In C++, this becomes:

```cpp
vector<Point> find_convex_hull_fp(const vector<Point>& points) {
    auto pairs = cartesian_product(points, points);

    auto is_hull_edge = [&](const pair<Point, Point>& edge) {
        return all_of(points.begin(), points.end(), [&](const Point& p) {
            return &p == &edge.first || &p == &edge.second ||
                   is_on_same_side(edge.first, edge.second, p);
        });
    };

    return filter(pairs, is_hull_edge)
           | transform([](auto&& p) { return vector{p.first, p.second}; })
           | flatten()
           | unique();
}
```

## Why This Matters: You Can Actually Prove Things

Here's the cool part: functional code is easier to **reason about**.

With the original code, proving correctness meant:
1. Tracking three loop variables
2. Understanding when the `break` happens
3. Verifying when `hull` gets updated

With the functional version:
1. `cartesian_product` generates all point pairs (obvious)
2. `is_hull_edge` is a direct translation of the mathematical definition
3. The composition uses standard, well-understood operations

I can even write tests that verify mathematical properties:

```cpp
// Convex hull property: all points should be inside the hull
TEST(ConvexHull, AllPointsInsideHull) {
    auto points = generate_random_points(100);
    auto hull = find_convex_hull_fp(points);

    for (const auto& p : points) {
        ASSERT_TRUE(is_point_inside_convex_polygon(p, hull));
    }
}
```

## Category Theory Sneaks In

Recently, I was writing a config parser with multiple operations that could fail:

```cpp
optional<int> parse_timeout(const string& str);
optional<string> parse_hostname(const string& str);
optional<Config> create_config(int timeout, const string& host);
```

The traditional way:

```cpp
optional<Config> parse_config(const string& timeout_str,
                              const string& host_str) {
    auto timeout = parse_timeout(timeout_str);
    if (!timeout) return nullopt;

    auto host = parse_hostname(host_str);
    if (!host) return nullopt;

    return create_config(*timeout, *host);
}
```

The functional way uses a pattern (some people call it a monad, but I just call
it useful):

```cpp
template<typename T, typename Func>
auto and_then(const optional<T>& opt, Func f)
    -> decltype(f(opt.value())) {
    if (!opt) return decltype(f(opt.value()))();
    return f(*opt);
}

optional<Config> parse_config_fp(const string& timeout_str,
                                 const string& host_str) {
    return and_then(parse_timeout(timeout_str), [&](int timeout) {
        return and_then(parse_hostname(host_str), [&](const string& host) {
            return create_config(timeout, host);
        });
    });
}
```

Mathematically, this is composition in the Kleisli category:
$$
f: A \to M(B), \quad g: B \to M(C) \\
g \circ_K f: A \to M(C)
$$

## Performance? Actually Better

People say functional code is slow. Modern C++ compilers are smart:

```cpp
// Hand-written "optimized" version
double sum_squares(const vector<double>& data) {
    double sum = 0.0;
    for (const auto& x : data) {
        sum += x * x;
    }
    return sum;
}

// Functional version
double sum_squares_fp(const vector<double>& data) {
    return fold(data, 0.0, [](double acc, double x) {
        return acc + x * x;
    });
}
```

With `-O3`, GCC generates identical assembly for both. The functional version is
actually safer—no loop variables, no bounds checking worries.

## My New Toolkit

Here's what functional thinking added to my C++ toolbox:

1. **map/filter/reduce** - The basics for working with collections
2. **Function composition** - `compose(f, g)(x) = f(g(x))`
3. **Currying** - `curry(f)(a)(b) = f(a, b)`
4. **Lazy evaluation** - Using `generator` or `ranges::view`

Like currying for configuration:

```cpp
auto create_server = curry([](int port, const string& host, Config config) {
    return Server{port, host, config};
});

auto create_local_server = create_server(8080, "localhost");
auto server = create_local_server(config);
```

## The Mindset Shift

Functional programming taught me something important: **code is math, and the
compiler is my proof assistant**.

Before: I wrote loops thinking "do this repeatedly".
Now: I write `fold` thinking "apply this associative operation".

Before: I wrote conditionals thinking "if this, then that".
Now: I write `filter` thinking "select elements satisfying this predicate".

This mindset lets me write code that's easier to prove correct. Last week I
found a bug and mentally traced it:

```
Given: filter(is_even, [1,2,3,4]) = [2,4]
Given: map(square, [2,4]) = [4,16]
Given: fold(add, 0, [4,16]) = 20
Therefore: sum of squares of even numbers = 20
```

Writing it down like that was the proof.

## Functional C++ in the Real World

This is how I write production code now:

```cpp
// HTTP request processing pipeline
auto handle_request = compose(
    validate_request,
    authenticate,
    parse_body<Order>,
    process_order,
    create_response
);

// Or with ranges
auto valid_orders = requests
    | views::filter(is_valid_order)
    | views::transform(parse_order)
    | views::filter([](const Order& o) { return o.total > 100.0; })
    | views::transform(apply_discount)
    | ranges::to<vector>();
```

This isn't "functional C++"—it's just C++. But it's C++ written with functional
thinking.

## Finally

When I started seeing loops through mathematical eyes, they stopped being loops
and became instances of algebraic structures. That perspective lets me write
code that's cleaner, more correct, and honestly more fun to write.

Maybe that's the end goal of programming: code stops being instructions and
becomes executable mathematics.
