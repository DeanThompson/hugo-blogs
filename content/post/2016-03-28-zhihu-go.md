+++
date = "2016-03-28T23:35:58+08:00"
draft = false
tags = ["go", "zhihu"]
categories = ["go"]
title = "zhihu-go: 知乎非官方 API库 with Go"
slug = "zhihu-go"
+++

我是知乎重度用户，每天都会花点时间在知乎上面看点东西。有段时间时间线里经常出现爬虫相关的话题，也看到不少直接爬知乎信息的项目；其中一个就是 [zhihu-python](https://github.com/egrcc/zhihu-python). 实际上 zhihu-python 不是一个完整的爬虫，正如其文档说明的那样，是一个 API 库，可以基于这些 API 实现一个爬虫应用。zhihu-python 实现了用户、问题、答案、收藏夹相关的信息获取类 API，对于大多数信息获取的目的已经足够。这个项目很受欢迎，然而说实话，代码质量一般，不过思路值得借鉴。

<!--more-->

恰巧我也是一个 [Go 语言](http://golang.org/) 爱好者，在之前的工作中也用 Go 写过项目。语法简单，开发效率高，性能很好。GitHub 上搜了一下，zhihu-python 或同类项目，并没有一个 Go 实现的版本。于是就想动手造个轮子，把 zhihu-python 移植到 Go，所以就有了标题里提到的 [zhihu-go](https://github.com/DeanThompson/zhihu-go). 主要是出于练手的目的，最近一年都在做 Python 开发，Go 还有点生疏了。因为是移植，最初的设计和实现思路很大程度上参考或模仿了 zhihu-python，后来在开发过程中，新增了一些 API，也删除了少数几个我认为没什么用的 API. 开发过程中又看到了一个 Python 3 版本的实现 [zhihu-py3](https://github.com/7sDream/zhihu-py3)，这个库也是受启发于 zhihu-python，代码质量也要更好，而且实现了更丰富的 API，尤其是关于操作类的，如点赞、收藏答案等。zhihu-go 也参考了 zhihu-py3 的一些 API 设计。截止到现在，zhihu-go 的完成度应该和 zhihu-python 差不多，还多了一些 API；比 zhihu-py3 少了活动、评论及操作类的 API，这些在 TODO list 都列了出来。

前几天在 V2EX 发了一个 [推广的帖子](http://v2ex.com/t/266372)，没想到反响还不错，收到不少支持和鼓励，GitHub 也在一两天内收获了 50 来个 star （个人最高）. 其实在这之前，还在 StuduGolang 发了 [一个主题](http://studygolang.com/topics/1528)，然而并没有人回复，带到 GitHub 的流量也很少，好像只有 1 个 star. golangtc 也发了，流量就更少了，可以忽略不计。

后续有时间简单分析一下源码，分享一下开发过程和心得。
