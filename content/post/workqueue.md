---
title: "workqueue"
date: 2017-10-15T06:42:15-07:00
tags: ["kubernetes", "go", "data structures", "composition", "v1.8.1"]
---

# An example of composition in Kubernetes

`workqueue` is a package that lives in the kubernetes/kubernetes repo ([for now][2]) under the path [k8s.io/staging/client-go/utils/][1].

The `workqueue` package exposes data structures that controllers use to manage operations on resources.

The lowest layer of the abstraction is the basic `queue` with an interface that looks like this (renamed to `Queue` for clarity):

```nosyntax
type Queue interface {
	Add(item interface{})
	Get() (item interface{}, shutdown bool)
	...
}
```

The implementation defined in this same file is a standard queue with some safety features that can be safely ignored.

## Extending the code

### DelayingQueue

There is another file in this package called [`delaying_queue.go`][3]. This defines a new interface called `DelayingQueue` that looks exactly like the `Queue` interface with one additional function, `AddAfter`:

```nosyntax
type DelayingQueue interface {
	Queue
	AddAfter(item interface{}, duration time.Duration)
}
```

`AddAfter` takes an item and a duration and adds the item to the queue after the duration (e.g. 30 minutes, 3 seconds, etc.) has passed.

The `DelayingQueue` interface is the `Queue` interface with one additional method. It composes the `Queue` interface and the `AddAfter` method into a new interface.

## Extending the code again

### RateLimiter

The `RateLimiter` is an interface that has a function called `When`. `When` takes an item and returns a duration. If the `RateLimiter` sees the same item multiple times it will increase the duration that it returns.

### RateLimitingQueue

The next step in the queue abstraction ladder is found in the file [`rate_limiting_queue.go`][4]. This takes the `DelayingQueue` interface and adds another method:

```nosyntax
type RateLimitingQueue interface {
	DelayingInterface
	AddRateLimited(item interface{})
	...
}
```

Something interesting happened here. The way an item is added to the queue became simpler than `DelayingQueue` but the behavior is more complex. The duration that was required in `AddAfter` is gone. Instead, the `RateLimitingQueue` uses a `RateLimiter` to manage the duration the `AddAfter` method requires.

When `AddRateLimited` gets called, the `RateLimitingQueue` uses the `RateLimiter` to find out how long the item should be delayed for before being added back to the queue. `AddRateLimited` calls `RateLimiter`'s `When` function and uses the returned value as the duration for `DelayingQueue`'s method `AddAfter`.

# Caveat

These interfaces are not quite as simple as they appear here. I omitted some functions for the sake of clarity. There is a lot more to these interfaces and implementations and I would encourage you to read through it if you're curious how a concurrent system like Kubernetes manages a queue.

# Bonus Tangent

If you're going to dive into the code directly, I suggest making sure you understand [`sync.Cond`][5] as that is the underpinning of the concurrency pattern found in the `workqueue` package. Interestingly there is [a proposal out to remove `sync.Cond`][6] from Go 2.0 and you will be hard pressed to find many examples of it. [This is one of the better posts I read about it.][7]

[1]: https://github.com/kubernetes/kubernetes/blob/v1.8.1/staging/src/k8s.io/client-go/util/workqueue/
[2]: https://github.com/kubernetes/kubernetes/blob/v1.8.1/staging/README.md
[3]: https://github.com/kubernetes/kubernetes/blob/v1.8.1/staging/src/k8s.io/client-go/util/workqueue/delaying_queue.go
[4]: https://github.com/kubernetes/kubernetes/blob/v1.8.1/staging/src/k8s.io/client-go/util/workqueue/rate_limitting_queue.go
[5]: https://golang.org/pkg/sync/#Cond
[6]: https://github.com/golang/go/issues/21165
[7]: http://openmymind.net/Condition-Variables/
