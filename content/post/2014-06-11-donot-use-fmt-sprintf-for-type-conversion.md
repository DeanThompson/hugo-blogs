+++
date = "2014-06-11T15:50:41+08:00"
draft = false
tags = ["go", "golang", "fmt", "type conversion"]
categories = ["golang"]
title = "不要用 fmt.Sprintf 做类型转换"
slug = "donnot-use-fmt-Sprintf-for-type-conversion"
+++

严格的讲，应该是在把 `int`，`float`等类型转换为字符串时，不要用 `fmt.Sprintf`，更好的做法是用标准库函数。`fmt.Sprintf` 的用途是格式化字符串，接受的类型是 interface{}，内部使用了反射。所以，与相应的标准库函数相比，`fmt.Sprintf` 需要更大的开销。大多数类型转换的函数都可以在 `strconv` 包里找到。

## int to string

整数类型转换为字符串，推荐使用 `strconv.FormatInt`（`int64`），对于 `int` 类型，`strconv.Itoa` 对前者做了一个封装。

比较一下 `strconv.FormatInt` 和 `fmt.Sprintf` 的时间开销：

```go
package main

import (
    "fmt"
    "strconv"
    "time"
)

const LOOP = 10000

var num int64 = 10000

func main() {
    startTime := time.Now()
    for i := 0; i < LOOP; i++ {
        fmt.Sprintf("%d", num)
    }
    fmt.Printf("fmt.Sprintf taken: %v\n", time.Since(startTime))

    startTime = time.Now()
    for i := 0; i < LOOP; i++ {
        strconv.FormatInt(num, 10)
    }
    fmt.Printf("strconv.FormatInt taken: %v\n", time.Since(startTime))
}
```

其中某一次运行结果：

```text
fmt.Sprintf taken: 2.995178ms
strconv.FormatInt taken: 1.057318ms
```

多次运行结果都类似，结论是：`fmt.Sprintf` 所需要的时间大约是 `strconv.FormatInt` 的 3 倍。

同理，对于 `float64` 类型，推荐使用 `strconv.FormatFloat`。测试代码和上面类似，得到的结论是：`fmt.Sprintf` 所需要的时间大约是 `strconv.FormatFloat` 的 1.1 倍。效果没有整型明显，但依然更高效。

## hexadecimal to string

十六进制数到字符串的转换也很常见，尤其是在一些加解密程序中，如获取 md5 值。 `encoding/hex` 包提供了十六进制数的编解码函数。

下面比较一下 `fmt.Sprintf` 和 `hex.EncodeToString` 的时间开销：

```go
package main

import (
    "crypto/md5"
    "encoding/hex"
    "fmt"
    "io"
    "time"
)

const LOOP = 10000

func makeMd5(data string) []byte {
    h := md5.New()
    io.WriteString(h, data)
    return h.Sum(nil)
}

func main() {
    s := "123456"
    hexBytes := makeMd5(s)
    s1 := fmt.Sprintf("%x", hexBytes)
    s2 := hex.EncodeToString(hexBytes)
    fmt.Println("result of fmt.Sprintf == hex.EncodeToString:", s1 == s2) // 确保结果一致

    start := time.Now()
    for i := 0; i < LOOP; i++ {
        fmt.Sprintf("%x", hexBytes)
    }
    fmt.Printf("fmt.Sprintf taken: %v\n", time.Since(start))

    start = time.Now()
    for i := 0; i < LOOP; i++ {
        hex.EncodeToString(hexBytes)
    }
    fmt.Printf("hex.EncodeToString taken: %v\n", time.Since(start))
}
```

这个程序某一次的运行结果是：

```text
result of fmt.Sprintf == hex.EncodeToString: true
fmt.Sprintf taken: 10.285488ms
hex.EncodeToString taken: 2.080457ms
```

多次运行结果都类似，可以得到一个结论：`fmt.Sprintf` 所需要的时间大约是 `hex.EncodeToString` 的 5 倍。

这里只讨论了三种数据类型，对于其他类型的数据也是类似的。总之，在需要转换成字符串时，即使对性能要求不高，都尽量不要用 `fmt.Sprintf`。

