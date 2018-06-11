+++
date = "2018-06-02T16:03:26+08:00"
title = "Python 日期和时间处理"
draft = false
slug = "python-date-time"
categories = ["python"]
tags = ["time", "python"]
+++

2012 年大四的时候写过一篇 [Python 时间戳和日期相互转换](/posts/2012/10/python-timestamp-to-timestr)，当时是初学 Python，对标准库也理解不深；随便找到一种解决方案就记录下来并发到博客上了。现在回看起来，其实太过繁琐了。然而从 Google Analytics 后台看，这竟然是点击率第二的文章，着实让我感到诧异。本着对读者负责的态度，有必要结合这些年的开发经验，再写一篇日期和时间处理的博客。

首先再次回答「Python 时间戳和日期相互转换」的问题。

## 时间戳转日期

```python
import datetime
import time

t = time.time()
print('Timestamp', t)

dt = datetime.datetime.fromtimestamp(t)
print('Datetime', dt)
```

输出：

```
Timestamp 1527927420.684622
Datetime 2018-06-02 16:17:00.684622
```

## 日期转时间戳

```python
import datetime

now = datetime.datetime.now()
print('Datetime', now)
print('Timestamp', now.timestamp())
```

输出：

```
Datetime 2018-06-02 16:18:42.170874
Timestamp 1527927522.170874
```
