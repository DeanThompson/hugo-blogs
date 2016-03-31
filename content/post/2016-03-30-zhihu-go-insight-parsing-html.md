+++
date = "2016-03-30T23:02:51+08:00"
draft = false
tags = ["go", "zhihu", "html"]
categories = ["go"]
title = "zhihu-go 源码解析：用 goquery 解析 HTML"
slug = "zhihu-go-insight-parsing-html-with-goquery"
+++

[上一篇博客](/posts/2016/03/zhihu-go/) 简单介绍了 [zhihu-go](https://github.com/DeanThompson/zhihu-go) 项目的缘起，本篇简单介绍一下关于处理 HTML 的细节。

因为知乎没有开发 API，所以只能通过模拟浏览器操作的方式获取数据，这些数据有两种格式：普通的 HTML 文档和某些 Ajax 接口返回的 JSON（返回的数据实际上也是 HTML）。其实也就是爬虫了，抓取网页，然后提取数据。一般来说从 HTML 文档提取数据有这些做法：正则、XPath、CSS 选择器等。对我来说，正则写起来比较复杂，代码可读性差而且维护起来麻烦；XPath 没有详细了解，不过用起来应该不难，而且 Chrome 浏览器可以直接提取 XPath. zhihu-go 里用的是选择器的方式，使用了 [goquery](https://github.com/PuerkitoBio/goquery).

goquery 是 "a little like that j-thing, only in Go"，也就是用 jQuery 的方式去操作 DOM. jQuery 大家都很熟，API 也很简单明了。本文不详细介绍 goquery，下面选几个场景（API）讲讲在 zhihu-go 里的应用。

<!--more-->

### 创建 Document 对象

goquery 暴露了两个结构体：`Document` 和 `Selection`. `Document` 表示一个 HTML 文档，`Selection` 用于像 jQuery 一样操作，支持链式调用。goquery 需要指定一个 HTML 文档才能继续后续的操作，有以下几个构造方式：

* `NewDocumentFromNode(root *html.Node) *Document`: 传入 `*html.Node` 对象，也就是根节点。
* `NewDocument(url string) (*Document, error)`: 传入 URL，内部用 `http.Get` 获取网页。
* `NewDocumentFromReader(r io.Reader) (*Document, error)`: 传入 `io.Reader`，内部从 reader 中读取内容并解析。
* `NewDocumentFromResponse(res *http.Response) (*Document, error)`: 传入 HTTP 响应，内部拿到 `res.Body`(实现了 `io.Reader`) 后的处理方式类似 `NewDocumentFromReader`.

因为知乎的页面需要登录才能访问（还需要伪造请求头），而且我们并不想手动解析 HTML 来获取 `*html.Node`，最后用到了另外两个构造方法。大致的使用场景是：

* 请求 HTML 页面（如问题页面），调用 `NewDocumentFromResponse`
* 请求 Ajax 接口，返回的 JSON 数据里是一些 HTML 片段，用 `NewDocumentFromReader`，其中 `r = strings.NewReader(html)`

为了方便举例说明，下文采用这个定义: `var doc *goquery.Document`.

### 查找到指定节点

`Selection` 有一系列类似 jQuery 的方法，`Document` 结构体内嵌了 `*Selection`，因此也能直接调用这些方法。主要的方法是 `Selection.Find(selector string)`，传入一个选择器，返回一个新的，匹配到的 `*Selection`，所以能够链式调用。

比如在用户主页（如 [黄继新](https://www.zhihu.com/people/jixin)），要获取用户的 BIO. 首先用 Chrome 定位到对应的 HTML：

```html
<span class="bio" title="和知乎在一起">和知乎在一起</span>
```

对应的 go 代码就是：

```go
doc.Find("span.bio")
```

如果一个选择器对应多个结果，可以使用 `First()`, `Last()`, `Eq(index int)`, `Slice(start, end int)` 这些方法进一步定位。

还是在用户主页，在用户资料栏的底下，从左往右展示了提问数、回答数、文章数、收藏数和公共编辑的次数。查看 HTML 源码后发现这几项的 class 是一样的，所以只能通过下标索引来区分。

先看 HTML 源码：

```html
<div class="profile-navbar clearfix">
<a class="item " href="/people/jixin/asks">提问<span class="num">1336</span></a>
<a class="item " href="/people/jixin/answers">回答<span class="num">785</span></a>
<a class="item " href="/people/jixin/posts">文章<span class="num">91</span></a>
<a class="item " href="/people/jixin/collections">收藏<span class="num">44</span></a>
<a class="item " href="/people/jixin/logs">公共编辑<span class="num">51648</span></a>
</div>
```

如果要定位找到回答数，对应的 go 代码是：

```go
doc.Find("div.profile-navbar").Find("span.num").Eq(1)
```

### 属性操作

经常需要获取一个标签的内容和某些属性值，使用 goquery 可以很容易做到。

继续上面获取回答数的例子，用 `Text() string` 方法可以获取标签内的文本内容，其中包含所有子标签。

```go
text := doc.Find("div.profile-navbar").Find("span.num").Eq(1).Text()    // "785"
```

需要注意的是，`Text()` 方法返回的字符串，可能前后有很多空白字符，可以视情况做清除。

获取属性值也很容易，有两个方法：

* `Attr(attrName string) (val string, exists bool)`: 返回属性值和该属性是否存在，类似从 `map` 中取值
* `AttrOr(attrName, defaultValue string) string`: 和上一个方法类似，区别在于如果属性不存在，则返回给定的默认值

常见的使用场景就是获取一个 a 标签的链接。继续上面获取回答的例子，如果想要得到用户回答的主页，可以这么做：

```go
href, _ := doc.Find("div.profile-navbar").Find("a.item").Eq(1).Attr("href")
```

还有其他设置属性、操作 class 的方法，就不展开讨论了。

### 迭代

很多场景需要返回列表数据，比如问题的关注者列表、所有回答，某个答案的点赞的用户列表等。这种情况下一般需要用到迭代，遍历所有的同类节点，做某些操作。

goquery 提供了三个用于迭代的方法，都接受一个匿名函数作为参数：

* `Each(f func(int, *Selection)) *Selection`: 其中函数 `f` 的第一个参数是当前的下标，第二个参数是当前的节点
* `EachWithBreak(f func(int, *Selection) bool) *Selection`: 和 `Each` 类似，增加了中途跳出循环的能力，当 `f` 返回 `false` 时结束迭代
* `Map(f func(int, *Selection) string) (result []string)`: `f` 的参数与上面一样，返回一个 string 类型，最终返回 []string.

比如获取一个收藏夹（如 [黄继新的收藏：关于知乎的思考](https://www.zhihu.com/collection/19573315)）下所有的问题，可以这么做（见 [zhihu-go/collections.go](https://github.com/DeanThompson/zhihu-go/blob/master/collection.go)）：

```go
func getQuestionsFromDoc(doc *goquery.Document) []*Question {
	questions := make([]*Question, 0, pageSize)
	items := doc.Find("div#zh-list-answer-wrap").Find("h2.zm-item-title")
	items.Each(func(index int, sel *goquery.Selection) {
		a := sel.Find("a")
		qTitle := strip(a.Text())
		qHref, _ := a.Attr("href")
		thisQuestion := NewQuestion(makeZhihuLink(qHref), qTitle)
		questions = append(questions, thisQuestion)
	})
	return questions
}
```

`EachWithBreak` 在 zhihu-go 中也有用到，可以参见 `Answer.GetVotersN 方法`：[zhihu-go/answer.go](https://github.com/DeanThompson/zhihu-go/blob/master/answer.go).

### 删除节点、插入 HTML、导出 HTML

有一个需求是把回答内容输出到 HTML，说白了其实就是修复和清洗 HTML，具体的细节可以看 [answer.go 里的 answerSelectionToHtml 函数](https://github.com/DeanThompson/zhihu-go/blob/master/answer.go#L222). 其中用到了一些需要修改文档的操作。

比如，调用 `Remove()` 方法把一个节点删掉：

```go
sel.Find("noscript").Each(func(_ int, tag *goquery.Selection) {
    tag.Remove() // 把无用的 noscript 去掉
})
```

在节点后插入一段 HTML:

```go
sel.Find("img").Each(func(_ int, tag *goquery.Selection) {
    var src string
    if tag.HasClass("origin_image") {
        src, _ = tag.Attr("data-original")
    } else {
        src, _ = tag.Attr("data-actualsrc")
    }
    tag.SetAttr("src", src)
    if tag.Next().Size() == 0 {
        tag.AfterHtml("<br>")   // 在 img 标签后插入一个换行
    }
})
```

在标签尾部 append 一段内容：

```go
wrapper := `<html><head><meta charset="utf-8"></head><body></body></html>`
doc, _ := goquery.NewDocumentFromReader(strings.NewReader(wrapper))
doc.Find("body").AppendSelection(sel)
```

最终输出为 html 文档：

```go
html, err := doc.Html()
```

## 总结

上面的例子基本涵盖了 zhihu-go 中关于 HTML 操作的场景，得益于 goquery 和 jQuery 的 API 风格，实现起来还是非常简单的。
