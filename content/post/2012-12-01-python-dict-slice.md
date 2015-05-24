+++
date = "2012-12-01T15:09:08+08:00"
draft = false
tags = ["python", "dict"]
categories = ["python"]
title = "Python字典切片"
slug = "python-dict-slice"
+++

python 的 `list`, `string`, `tuple` 都提供了切片操作，用起来非常方便。有时候会需要对字典进行截取，只需要其中一部分数据。然而 python 的 `dict` 没有提供类似的切片操作，所以就得要自己实现。

其实也很简单：先取出所有 keys，再对 keys 切片，然后用得到的键去字典里找值重新创建一个新的字典。示例代码：

```python
def dict_slice(adict, start, end):
    keys = adict.keys()
    dict_slice = {}
    for k in keys[start:end]:
        dict_slice[k] = adict[k]
    return dict_slice
```

----
**EDIT 2013-10-26 01:13**

补充一个一行的版本（one-liner）:

```python
dict_slice = lambda adict, start, end: dict((k, adict[k]) for k in adict.keys()[start:end])
```

这行代码主要是用了 `lambda` 来创建一个匿名函数，再用 built-in 函数 `dict()` 来生成新的字典。作用和上面的函数一模一样，调用方式也是一样的。如果是 python 2.7 及以上的版本，还可以用 dict comprehension 来替换 `dict()` 函数：

```python
dict_slice = lambda adict, start, end: { k:adict[k] for k in adict.keys()[start:end] }
```

这个看起来和 list comprehension 就很像了。非常优雅，且节省空间 ：）

----

简单验证：

```python
>>> d = {}.fromkeys(range(10), 5)
>>> d
{0: 5, 1: 5, 2: 5, 3: 5, 4: 5, 5: 5, 6: 5, 7: 5, 8: 5, 9: 5}
>>>
>>> slice = dict_slice(d, 3, 5)
>>> slice
{3: 5, 4: 5}
>>>
>>> slice = dict_slice(d, 4, 8)
>>> slice
{4: 5, 5: 5, 6: 5, 7: 5}
>>>
>>> slice = dict_slice(d, 5, -1)
>>> slice
{5: 5, 6: 5, 7: 5, 8: 5}
```

在某些场景下，如果需要对字典的切片有其他需求，如字典按键值排序等，还可以在创建新字典之前进行处理。

