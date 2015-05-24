+++
date = "2014-06-03T16:50:50+08:00"
draft = false
tags = ["go", "golang", "sort", "interface"]
categories = ["golang"]
title = "Golang 排序"
slug = "sort-in-golang"
+++

## Interface 接口

Go 语言标准库提供了排序的package sort，也实现了对 `int`， `float64` 和 `string` 三种基础类型的排序接口。所有排序调用 `sort.Sort`，内部根据排序数据个数自动切换排序算法（堆排、快排、插排）。下面这段代码出自 Go 标准库 sort/sort.go：

```go
func quickSort(data Interface, a, b, maxDepth int) {
    for b-a > 7 {
        if maxDepth == 0 {
            heapSort(data, a, b)
            return
        }
        maxDepth--
        mlo, mhi := doPivot(data, a, b)
        // Avoiding recursion on the larger subproblem guarantees
        // a stack depth of at most lg(b-a).
        if mlo-a < b-mhi {
            quickSort(data, a, mlo, maxDepth)
            a = mhi // i.e., quickSort(data, mhi, b)
        } else {
            quickSort(data, mhi, b, maxDepth)
            b = mlo // i.e., quickSort(data, a, mlo)
        }
    }
    if b-a > 1 {
        insertionSort(data, a, b)
    }
}

// Sort sorts data.
// It makes one call to data.Len to determine n, and O(n*log(n)) calls to
// data.Less and data.Swap. The sort is not guaranteed to be stable.
func Sort(data Interface) {
    // Switch to heapsort if depth of 2*ceil(lg(n+1)) is reached.
    n := data.Len()
    maxDepth := 0
    for i := n; i > 0; i >>= 1 {
        maxDepth++
    }
    maxDepth *= 2
    quickSort(data, 0, n, maxDepth)
}
```

这里不详细探讨排序算法的实现和性能细节，主要写一下如何使用标准库对基础数据进行排序，以及如何实现对自定义类型的数据进行排序。

标准库提供一个通用接口，只要实现了这个接口，就可以通过调用 `sort.Sort` 来排序。

```go
type Interface interface {
    // Len is the number of elements in the collection.
    Len() int
    // Less returns whether the element with index i should sort
    // before the element with index j.
    Less(i, j int) bool
    // Swap swaps the elements with indexes i and j.
    Swap(i, j int)
}
```

## 基本数据类型的排序

`Interface` 接口的三个函数分别用于获取长度（`Len`）、大小比较（`Less`）和交换（`Swap`）。对 `int`、`float64` 和 `string` 的排序，标准库已经做好了封装，直接调用即可。以 `int` 为例简单说明：

```go
package main                                                                                                                                                                                                 

import (
    "fmt"
    "sort"
)

func main() {
    a := []int{100, 5, 29, 3, 76} 
    fmt.Println(a)     // [100 5 29 3 76]
    sort.Ints(a)       // sort.Sort(IntSlice(a)) 的封装
    fmt.Println(a)     // [3 5 29 76 100]，默认的 Less() 实现的是升序

    a = []int{100, 5, 29, 3, 76} 
    fmt.Println(a)     // [100 5 29 3 76]
    sort.Sort(sort.Reverse(sort.IntSlice(a)))
    fmt.Println(a)     // [100 76 29 5 3]
}
```

对 `float64` 和 `string` 的排序，和上面类似。需要注意的是，默认的 `sort.Less` 实现的是升序排列，如果想要让结果降序，可以先用 `sort.Reverse` 包装一次。这个调用会得到一个 `reverse` 的类型，包含一个 `Interface` 的匿名字段，其 `Less` 函数与 `Interface` 里的相反，从而实现逆序。

## 自定义数据类型的排序

如果要对自定义的数据类型进行排序，需要实现 `sort.Interface` 接口，也就是实现 `Len`、`Less` 和 `Swap` 三个函数。很多场景下 `Len` 和 `Swap` 基本上和数据类型无关，所以实际上只有 `Less` 会有差别。

例如有个游戏下载排行榜，知道游戏ID和对应的下载量，需要把数据根据下载量进行排序。

```go
package main

import (
    "fmt"
    "math/rand"
    "sort"
)

type GameDownloadItem struct {
    GameID        int // 游戏ID
    DownloadTimes int // 下载次数
}

func (self GameDownloadItem) String() string {
    return fmt.Sprintf("<Item(%d, %d)>", self.GameID, self.DownloadTimes)
}

type GameDownloadSlice []*GameDownloadItem

func (p GameDownloadSlice) Len() int {
    return len(p)
}

func (p GameDownloadSlice) Swap(i int, j int) {
    p[i], p[j] = p[j], p[i]
}

// 根据游戏下载量 降序 排列
func (p GameDownloadSlice) Less(i int, j int) bool {
    return p[i].DownloadTimes > p[j].DownloadTimes
}

func main() {
    a := make(GameDownloadSlice, 7)
    for i := 0; i < len(a); i++ {
        a[i] = &GameDownloadItem{i + 1, rand.Intn(1000)}
    }

    fmt.Println(a)
    sort.Sort(a)
    fmt.Println(a)
}
```

第一次输出结果是随机（每次运行结果都一样）生成的未排序的数据：

```text
[<Item(1, 81)> <Item(2, 887)> <Item(3, 847)> <Item(4, 59)> <Item(5, 81)> <Item(6, 318)> <Item(7, 425)>]
```

排序后：

```text
[<Item(2, 887)> <Item(3, 847)> <Item(7, 425)> <Item(6, 318)> <Item(1, 81)> <Item(5, 81)> <Item(4, 59)>]
```

## Vs. Python

相比之下，Python 里的排序就非常简单便捷了，直接调用 `list` 的 `sort` 方法（in-place）即可，还可以用 built-in 函数 `sorted` （返回新列表）。对于自定义类型指定属性，或 tuple 指定列的排序也很简单，只需要重新定义一下 `sort` 方法的 `key` 参数。对于上面游戏下载量排序的例子，下面是 python 实现版本：

```python
#!/usr/bin/env python                                                                                                                                                                                        
# -*- coding: utf-8 -*-

import random

class GameDownloadItem(object):

    def __init__(self, game_id, download_times):
        self.game_id = game_id
        self.download_times = download_times

    def __str__(self):
        return '<Item(%d, %d)>' % (self.game_id, self.download_times)

def display(items):
    for item in items:
        print item,
    print '\n'


if __name__ == "__main__":
    items = [GameDownloadItem(i+1, random.randrange(1000)) for i in range(7)]
    display(items)

    items.sort(key=lambda item: item.download_times, reverse=True)
    display(items)
```

某一次的执行结果：

```text
<Item(1, 819)> <Item(2, 959)> <Item(3, 812)> <Item(4, 193)> <Item(5, 408)> <Item(6, 884)> <Item(7, 849)> 

<Item(2, 959)> <Item(6, 884)> <Item(7, 849)> <Item(1, 819)> <Item(3, 812)> <Item(5, 408)> <Item(4, 193)> 
```

