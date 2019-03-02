+++
date = "2015-11-28T22:32:35+08:00"
draft = false
tags = ["go", "jpush"]
categories = ["go"]
title = "极光推送 Go SDK"
slug = "jpush-api-go-client"
+++

[极光推送](https://www.jpush.cn/) 是国内最早的第三方消息推送服务，官方提供了多种语言的 SDK 和 REST API，详情见 [官方文档](http://docs.jpush.io/server/server_overview/)。遗憾的是缺少一个 Go 语言版本的 SDK，于是我就动手造轮子，封装了一个 Go 的版本。

实际上这个项目在今年 3 月份就完成了主要的推送相关的接口，在 GitHub 上也收获了几个 star 和 fork. 最近几天突然兴起，又翻出来把 device, tag, alias, report 的一些相关接口也封装完成了。

啰嗦了一大堆，差点忘了最重要的东西，下面给出链接：

- 源代码和示例：[https://github.com/DeanThompson/jpush-api-go-client](https://github.com/DeanThompson/jpush-api-go-client)
- 官方文档：[http://docs.jpush.io/server/rest_api_v3_push/](http://docs.jpush.io/server/rest_api_v3_push/)

欢迎使用，并 [反馈 issues](https://github.com/DeanThompson/jpush-api-go-client/issues) 或 [创建 pull request](https://github.com/DeanThompson/jpush-api-go-client/pulls).

<!--more-->

