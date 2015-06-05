+++
date = "2012-10-21T18:53:51+08:00"
draft = false
tags = ["python", "time"]
categories = ["python"]
title = "Python 时间戳和日期相互转换"
slug = "python-timestamp-to-timestr"
+++

在写Python的时候经常会遇到时间格式的问题，每次都是上 google 搜索然后找别人的博客或网站来参考。现在自己简单总结一下，方便以后查询。

首先就是最近用到的时间戳（timestamp）和时间字符串之间的转换。所谓时间戳，就是从 1970 年 1 月 1 日 00:00:00 到现在的秒数。那关于为什么是1970年这个特殊的日期，这篇文章有个简单明了的介绍：

> [为什么计算机时间要从1970年1月1日开始算起？](http://www.scriptlover.com/static/1071-%E6%97%A5%E6%9C%9F-%E6%97%B6%E9%97%B4-%E7%BC%96%E7%A8%8B-%E6%95%B0%E6%8D%AE%E5%BA%93)

<!--more-->

在Python里，时间戳可以通过 `time` 模块里的 `time()` 方法获得，比如:

```python
In [1]: import time

In [2]: time.time()
Out[2]: 1350816710.8050799
```

这个值对人来说是不友好的，所以有时候需要转换为一定的格式方便人理解。我们可以调用 `time.strftime()` 函数来达到这个目的。根据 `strftime()` 函数的文档，我猜这个名称应该是 “string format time” 的简写，也就是字符串格式的时间。这个方法需要两个参数，其中一个是时间格式，一个是一个9元组，第二个参数可选，默认为 `time.localtime()` 的返回值。而那个9元组其实是 `struct_time`，由9个元素组成的元组(tuple)，也是一种时间表示的格式。比如

```python
In [5]: import time

In [6]: time.localtime()
Out[6]: time.struct_time(tm_year=2012, tm_mon=10, tm_mday=21, tm_hour=19, tm_min=4, tm_sec=25, tm_wday=6, tm_yday=295, tm_isdst=0)
```

具体的含义，前6个应该很明显，那么后三个分别是：weekday(0-6)，在一年中的第几天(1-366)，是否是夏令时（默认-1）。现在再来看看如何把时间戳转换为指定格式的字符串形式。很简单，直接上代码

```python
In [8]: import time

In [9]: st = time.localtime(1350816710.8050799)
 
In [10]: time.strftime('%Y-%m-%d %H:%M:%S', st)
Out[10]: '2012-10-21 18:51:50'
```

先用 `localtime()` 把时间戳转换为 `struct_time`， 然后传给 `strftime` 转换为指定格式的字符串。那么反过来呢？
同样需要先转换为 `struct_time`，这个工作由 `time.strptime()` 函数完成。`strptime` 中的 `p` 应该是 parse 的意思，原型是:
    
```python
strptime(string, format) -> struct_time
```

把字符串形式的时间按照指定格式解析，转换为 `struct_time`。然后传给`time.mktime()` 完成最后的工作，整个过程是:

```python
In [12]: import time
 
In [13]: st = time.strptime('2012-10-21 18:51:50', '%Y-%m-%d %H:%M:%S')
 
In [14]: time.mktime(st)
Out[14]: 1350816710.0
```

最后，有两篇参考文章：

- Python中时间戳与时间字符串互相转化: [http://www.coder4.com/archives/2239](http://www.coder4.com/archives/2239)
- Python中time模块详解（很好）:[http://qinxuye.me/article/details-about-time-module-in-python/](http://qinxuye.me/article/details-about-time-module-in-python/)

