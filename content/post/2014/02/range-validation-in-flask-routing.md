+++
date = "2014-02-26T23:15:42+08:00"
draft = false
tags = ["python", "flask", "web"]
categories = ["python"]
title = "Flask 路由做范围限制"
slug = "range-validation-in-flask-routing"
+++

这其实是我之前在 StackOverflow 上回答过的一道题，令我感到意外的是，这个问题只有我一个人回答，而且我也获得了 8 个赞同。小小的成就感。

# 1. What
原题在这里：[How to validate integer range in Flask routing (Werkzeug)?](http://stackoverflow.com/questions/19076226/how-to-validate-integer-range-in-flask-routing-werkzeug/)

简单翻译一下，大致如下：

Flask 应用里面有一个这样的路由

```python
from foo import get_foo

@app.route("/foo/<int:id>")
def foo_id(id):
    return render_template('foo.html', foo = get_foo(id))
```
 
其中 `id` 的取值是 `1～300`，如何在路由层级做这个验证？也就是一个类似于这样的东西 `@app.route("/foo/<int:id(1-300)")`.

<!--more-->

# 2. How
这个问题其实对我很有启发，虽然平时都在用 Flask 做项目，但是没有考虑过在 router 层面做验证。虽然在应用场景中可能用处不大，但至少可能存在这个选项，在一些特殊的场景下可以很方便的处理非法请求。

虽然没用过参数验证，但是对 Flask 的路由规则还是比较熟悉的，也用过转换器（converter）。整体而言，Flask 基于一个 [WSGI Utility Library: Werkzeug](http://werkzeug.pocoo.org/) 和 [模板引擎 Jinja2](http://jinja.pocoo.org)，其中路由规则就是基于 Werkzeug 的。Werkzeug 提供了几种 builtin converters 用于将 URL 里的参数转换成对应 python 的数据类型，而事实上这就已经进行了一次类型检查。

## 2.1 Builtin Converters
如前所述，Werkzeug 提供了几种 [builtin converters](http://werkzeug.pocoo.org/docs/routing/#builtin-converters)，分别是：

- `class werkzeug.routing.UnicodeConverter(map, minlength=1, maxlength=None, length=None)`：字符串转换器，接受除了路径类型（含有 `/`）的所有字符串，这也是默认的转换器。
- `class werkzeug.routing.PathConverter(map)`：路径类型转换器，一般用得不多吧。
- `class werkzeug.routing.IntegerConverter(map, fixed_digits=0, min=None, max=None)`：整型转换器，接受并转换成 `int` 类型，不支持负数。
- `class werkzeug.routing.FloatConverter(map, min=None, max=None)`：浮点型转换器，接受并转换成 `float` 类型，不支持负数。
- `class werkzeug.routing.AnyConverter(map, *items)`：匹配任意一个给定的选项，这些选项可以是 python 标识符或字符串。

从文档里可以看到，有些转换器是支持一些简单的范围验证。如 UnicodeConverter 可以检查字符串的最小长度（`minlength`）、最大长度（`maxlength`）或者指定长度（`length`）。IntergerConverter 和 FloatConverter 都可以指定最小值（`min`）和最大值（`max`）。所以看完这些，就可以解决最开始的问题了。

## 2.2 Solution
回到原题，是需要对 `id` 做范围限制（`1～300`），因此路由就可以这样写了（[我的回答](http://stackoverflow.com/a/19076418/1461780)）：

```python
from foo import get_foo

@app.route("/foo/<int(min=1, max=300):id>")
def foo_id(id):
    return render_template('foo.html', foo = get_foo(id))
```

这个路由就限定了 `id` 的范围，对于超出范围的请求，如 `/foo/1024/`，就会找不到对应的路由，因此会返回 `404`。

# 3. End
题外话，其实题主开始的时候是在函数内部做了参数检测（我也基本这么干），而且最后也没有采用在路由做限制的方法。原因上面已经说了，就是对于超出范围的请求，会直接返回 `404`，某些情况下这是可以接受的，但另外的情况下最好能让用户知道他的请求到底哪里出了问题。用哪种方案取决于具体的应用场景，但对我来说至少多了一个选项，也对 converters 相关的内容更了解了一些。

