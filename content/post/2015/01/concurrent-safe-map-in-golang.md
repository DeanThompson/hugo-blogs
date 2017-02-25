+++
date = "2015-01-12T15:01:15+08:00"
draft = false
tags = ["go", "golang", "map", "concurrent-safe", "hash"]
categories = ["golang"]
title = "Golang 并发安全的 map 实现"
slug = "concurrent-safe-map-in-golang"
+++

Golang 里面 map 不是并发安全的，这一点是众所周知的，而且官方文档也很早就给了解释：[Why are map operations not defined to be atomic?](http://golang.org/doc/faq#atomic_maps). 也正如这个解释说的一样，要实现一个并发安全的 map 其实非常简单。

## 并发安全

实际上，大多数情况下，对一个 map 的访问都是读操作多于写操作，而且读的时候，是可以共享的。所以这种场景下，用一个 `sync.RWMutex` 保护一下就是很好的选择：

```go
type syncMap struct {
    items map[string]interface{}
    sync.RWMutex
}
```

上面这个结构体定义了一个并发安全的 string map，用一个 map 来保存数据，一个读写锁来保护安全。这个 map 可以被任意多的 goroutine 同时读，但是写的时候，会阻塞其他读写操作。添加上 `Get`，`Set`，`Delete` 等方法，这个设计是能够工作的，而且大多数时候能表现不错。

但是这种设计会有些性能隐患。主要是两个方面：

1. 读写锁的粒度太大了，保护了整个 map 的访问。写操作是阻塞的，此时其他任何读操作都无法进行。
2. 如果内部的 map 存储了很多 key，GC 的时候就需要扫描很久。

<!--more-->

## 「分表」

一种解决思路是“分表”存储，具体实现就是，基于上面的 `syncMap` 再包装一次，用多个 `syncMap` 来模拟实现一个 map：

```go
type SyncMap struct {
    shardCount uint8
    shards     []*syncMap
}
```

上面这种设计用了一个 `*syncMap` 的 slice 来保存数据，`shardCount` 提供了分表量的可定制性。实际上 `shards` 同样可以实现为 `map[string]*syncMap`。

在这种设计下，数据（key:value）会被分散到不同的 `syncMap`，而每个 `syncMap` 又有自己底层的 map。数据分散了，锁也分散了，能够很大程度上提高随机访问性能。而且在数据量大、高并发、写操作频繁的场景下，这种提升会更加明显。

那么数据如何被分配到指定的分块呢？一种很通用也很简单的方法就是 hash. 字符串的哈希算法有很多，byvoid 大神实现和比较了多种字符串 hash 函数（[各种字符串Hash函数比较](https://www.byvoid.com/blog/string-hash-compare/)），得出结论是：“BKDRHash无论是在实际效果还是编码实现中，效果都是最突出的”。这里采用了 BKDRHash 来实现：

```golang
const seed uint32 = 131 // 31 131 1313 13131 131313 etc..

func bkdrHash(str string) uint32 {
    var h uint32

    for _, c := range str {
        h = h*seed + uint32(c)
    }

    return h
}

// Find the specific shard with the given key
func (m *SyncMap) locate(key string) *syncMap {
    return m.shards[bkdrHash(key)&uint32((m.shardCount-1))]
}
```

`locate` 方法调用 `bkdrHash` 函数计算一个 `key` 的哈希值，然后用该值对分表量取模得到在 slice 的 `index`，之后就能定位到对应的 `syncMap`.

这种实现足够简单，而且也有不错的性能表现。除了基本的 `Get`、`Set`、`Delete` 等基本操作之外，迭代（`range`）功能也非常有用。更多的功能和细节，都可以在源码里找到答案： [https://github.com/DeanThompson/syncmap](https://github.com/DeanThompson/syncmap).

