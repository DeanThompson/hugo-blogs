+++
date = "2014-12-18T15:35:38+08:00"
draft = false
tags = ["go", "golang", "defer"]
categories = ["golang"]
title = "Golang 的 defer 语句"
slug = "defer-in-golang"
+++

Golang 的 `defer` 语句是个非常有用的语法，可以把一些函数调用放到一个列表里，在函数返回前延迟执行。这个功能可以很方便的在函数结束前处理一些清理操作。比如关闭打开的文件，关闭一个连接，解锁，捕捉 panic 等。

[这篇 Go Blog](http://blog.golang.org/defer-panic-and-recover) 用例子讲解了 `defer` 的用途和使用规则。总结一下主要就是三点：

- 传递给 `defer` 语句的参数是在添加时就计算好的。比如下面的函数的输出将会是 `0`.

```golang
func a() {
    i := 0
    defer fmt.Println(i)
    i++
    return
}
```

- 多个 `defer` 语句的执行顺序类似于 stack，即 Last In First Out. 比如下面的函数的输出将会是 `3210`.

```golang
func b() {
    for i := 0; i < 4; i++ {
        defer fmt.Print(i)
    }
}
```

- `defer` 语句可能会读取并修改函数的命名返回值（named return values）。比如下面的函数的返回值将会是 `2` ，而不是 `1`.

```golang
func c() (i int) {
    defer func() { i++ }()
    return 1
}
```

<!--more-->

`defer` 语句配合 `panic` 和 `recover` 可以实现其它语言里的捕捉异常（try-catch-finally），在上面给出的链接里也有描述。

`defer` 实在是一个非常好用的语法糖，平时写代码时也经常（几乎不可避免）用到。实际上，`defer` 也是有些额外的开销的。

最近在看 [revel 框架](https://github.com/revel/revel) 的一些源代码，其 cache 模块用了 robfig 实现的一个包 go-cache。go-cache 是一个 in-memroy 的 key:value 缓存实现，[其中一个方法源码如下](https://github.com/robfig/go-cache/blob/master/cache.go#L65)：

```golang
// Add an item to the cache, replacing any existing item. If the duration is 0,
// the cache's default expiration time is used. If it is -1, the item never
// expires.
func (c *cache) Set(k string, x interface{}, d time.Duration) {
    c.Lock()
    c.set(k, x, d)
    // TODO: Calls to mu.Unlock are currently not deferred because defer
    // adds ~200 ns (as of go1.)
    c.Unlock()
}
```

这里没有用 `defer` 来调用 `Unlock`，而且在代码里明确注释说 `defer` 会增加大约 200ns 的延迟。这是个很有意思的注释，因为平时虽然一直在用 `defer`，却从没考虑过这一点。robfig 说 `defer` 大概需要 200ns，一时兴起写了个[简单的 benchmark 测试](https://gist.github.com/DeanThompson/48365dc9472e0a64dba1)，来看看 Go 1.4 里究竟如何。

这是某一次测试的结果：

```text
testing: warning: no tests to run
PASS
BenchmarkDeferredUnlock     10000000            134 ns/op
BenchmarkNotDeferredUnlock  30000000            40.6 ns/op
```

可以看出，`defer` 大概需要 94ns，这对绝大多数应用来说几乎都是无关紧要的。

