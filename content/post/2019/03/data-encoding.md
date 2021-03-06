+++
date = "2019-03-02T16:40:45+08:00"
title = " Designing Data-Intensive Applications 读书笔记（1） —— 数据编码"
draft = false
slug = "data-encoding"
categories = ["devops"]
tags = ["devops", "notes"]

+++

最近一段时间都在读 *Designing Data-Intensive Applications* 这本书，中文名叫《数据密集型应用系统设计》。进度比较慢，但感觉很有意思，获益匪浅。在读第四章 *Encoding and Evolution* （数据编码与演化）时，脑海里时常浮现出自己的开发经历，颇有共鸣。因此准备结合书本内容和自身体验，总结成文字作为记录。这一篇主要讨论编码。

## 编码和解码

在程序世界里，数据通常有两种不同的表现形式：内存和文件（网络）。在内存中，数据保存在对象、结构体、列表、哈希表等结构中，这些数据结构针对 CPU 的高效访问和操作进行了优化。而把数据写入文件或通过网络发送时，需要将其转换成字节序列。

从内存中的表示到字节序列的转化称为编码或序列化，反之称为解码或反序列化。

<!--more-->

## 编码格式

只要程序发生 IO 或其他程序进行数据交换时，就需要进行编解码。每种场景的需求和特点各异，随着时间推移，诞生了很多中编码格式。从通用性的角度来看，可以划分为两大类：语言特定的格式和通用格式。

### 语言特定的格式

很多语言都有特定的编码格式，并且以标准库的形式提供编码和解码功能。我使用过的有 Python 的 pickle 和 Go 的 gob. 这些库的主要好处是使用方便，功能强大。以 Python 的 pickle 为例，不仅能处理常见的数据格式，[还能处理函数、类和对象](https://docs.python.org/3/library/pickle.html#what-can-be-pickled-and-unpickled). 但也存在一些问题：

1. 跨语言共享非常困难。语言特定的格式就类似于一种私有加密算法，其他程序（语言）基本上无法理解。2013 年曾做过用 Go 重构一个 Python 应用的项目。项目里用到了 Redis，但是缓存的数据都是用 pickle 序列化的，Go 语言无法解码。当时刚参加工作，经验不足，不知道 pickle 是 Python 特有的，刚开始还找了很久 Go 的解码库（当然没找到）。后来经老大提醒，把缓存全部改成 JSON.
2. 存在安全隐患。为了在相同的对象类型中恢复数据，解码过程要能实例化任意的类，就有可能执行一些危险的代码。[Understanding Python pickling and how to use it securely](https://www.synopsys.com/blogs/software-security/python-pickling/) 用例子讲述了 Python pickle 的安全隐患和一些可行的放缓措施。
3. 书中还提到了多版本的兼容性和编解码效率问题。

### 通用格式

计算机上运行的程序由各种各样的编程语言实现，因此必然需要一些通用和标准格式来支持不同语言之间的数据交换。这些格式可以分为两种：文本格式和二进制格式。

#### 文本格式

常见的文本格式有 JSON、XML 和 CSV，其中 CSV 可以泛化为分隔符文本文件。这些编码格式应用非常广泛，基本上所有语言都能正确编码和解码。而且可读性良好， 很适合人类阅读理解。

这些格式解决了跨语言的障碍，但也有一些的问题：

1. 对数字的处理存在缺陷。XML 和 CSV 无法区分数字和碰巧由数字组成的字符串；JSON 有字符串和数字类型，但不区分整数和浮点数。书里还提到 JavaScript 在处理大于 `2**53` 的数字时会有精度丢失的现象，但这只能说时 JavaScript 语言的问题，不是 JSON 的不足（JSON 只是一种文本格式）。不过我确实在实际工作中被这个问题坑过一次：从 TiDB 同步数据到 ElasticSearch，在 Kibana 查看时总是会有些 BIGINT (int64) 类型的数据和 TiDB 对应不上（ElasticSearch 存储的是对的）。查明原因后，为了方便查看，不得不把类型转换成字符串再重新同步。
2. 不支持二进制数据。用 Python 开发了一个异构数据源的数据同步系统（项目代号为 pigeon），为了方便扩展和解耦，把同步过程拆成了 dump 和 load 两个步骤，用 CSV 文件作为数据交换格式。在大部分情况下这种设计能很好的工作，但最大的缺陷就是不支持二进制数据。各种数据库系统都有二进制类型，而且也非常有用（存储图片、压缩或加密的数据等）。一种可行的方案是用 base64 把二进制字符串编码成文本字符串，但会带来 33% 的数据膨胀。
3. XML 和 JSON 的每条记录都要保存元素标记、字段名等信息，导致大量冗余。CSV 相对来说更加紧凑，最多用第一行保存每一列的字段名称。但不管是否有冗余，相对二进制格式而言，都会占用大量磁盘空间，当数据量大时，就要使用压缩算法进行压缩保存。
4. CSV 没有模式，其实就是一种分隔符文件，当数据内部存在分隔符就可能会带来麻烦。虽然可以使用转义字符和 quoting，但并不是所有解析器都能正确解析。使用 pigeon 的时候就发现，MySQL 对 CSV 的容错性似乎不如 Python 的标准库 `csv`.
4. 用 Python 写入 CSV 时，会把 `None` 编码成空字符串，从而导致解码时无法区分。因此在 pigeon 里大部分场景下会把 `None` 编码为 `NULL` 或 `\N`.

尽管存在这些或那些缺陷，JSON、XML 和 CSV 的应用非常广泛，编解码工具也很成熟丰富。在 Web 开发领域，传统的 Web Service 大量使用 XML，随着 Web 技术的发展和， JSON 变得越来越流行. 在数据库和数据分析领域，则经常使用 CSV 来作为数据交换格式，基本上常见的数据库都原生支持导入 CSV 文件（这也是 pigeon 选择 CSV 的重要原因之一）。

#### 二进制格式

##### JSON 和 XML 的二进制变体

因为以上原因，也催生了很多这些文本格式的二进制变体。如 JSON 系的 MessagePack、BSON、BJSON、UBJSON、BISON，XML 系的 WBXML 和 Fast Infoset. 这些格式被很多细分领域所采用，但都没有 JSON 和 XML 那样广泛。

MessagePack（和其他同类二进制编码）对空间缩减有限（书中的例子是 81 字节到 66 字节），而且牺牲了可读性，作者似乎认为这并不值得。不过另一个好处是，一般二进制的解析速度会更快，还有一些格式扩展了数据类型，比如可以区分整数和浮点数，或者增加了对二进制字符串的支持。

##### Thrift 和 Protocol Buffers

[Apache Thrift](https://thrift.apache.org/) 和 [Protocol Buffers](https://developers.google.com/protocol-buffers/) 分别诞生自 Facebook 和 Google，都在 2007~2008 期间贡献到开源社区。两种格式都需要定义 schema (IDL, Interface definition language)，而且都有对应的代码生成工具，可以自动生成多种语言的解析代码。

Thrift 和 Protocol Buffers 类似，每个字段用标签（tag, 数字 1, 2, 3...）表示，所以更加紧凑，可以节省大量空间。由于编码不会引用字段名，所以只要保证标签不变， schema 里的字段名可以随意更改（JSON 和 XML 不行）。此外每个字段都有明确的数据类型，还有 `optional` 和 `required` 约束，可以用于数据合法性校验。

Thrift 有 BinaryProtocol 和 CompactProtocol 两种编码格式，书中的例子生成的二进制序列分别是 59 字节和 34 字节。Protocol Buffers 的结果是 33 字节。

因为这些编码格式更紧凑、高效，能自动生成客户端和服务端代码，往往用于实现高性能的 RPC 服务。其实 Thrift 本身就是一个 RPC 框架，Hadoop 生态里的组件就大量使用 Thrift. Protocol Buffers 没有实现 RPC 框架，但 Google 基于此开发了 [gRPC](https://grpc.io/)，应用也十分广泛，比如 TiDB 组件的内部通信就用了 gRPC.

## 总结

跟其他技术（比如数据库）一样，每种格式都有各自的优点和缺陷，抛开使用场景单纯讨论优劣是没有意义的。下表是结合书中内容和自己的理解，从几个维度定性的比较了这些格式的特点。不一定对，仅供参考。

编码格式 | 可读性 | schema | 性能 | 空间 | 代码生成 | 复杂度 | 适用场景举例
----|----|----|----|----|----|----|----
JSON | 好 | 有，复杂 | 中等 | 大 | 无 | 很低 | Web
XML | 较好 | 有，复杂 | 中等 | 很大 | 无 | 中等 | 配置, UI, SOAP
CSV | 好 | 无 | 高 | 中等 | 无 | 低 | 关系型数据
MessagePack | 差 | 无 | 较高 | 较小 | 无 | 低 | Web
Thrift |差|有|很高|很小|有|高|RPC
Protocol Buffers |差|有|很高|很小|有|高|RPC

> 文末低调宣传一下，本文也发布在个人公众号: [https://mp.weixin.qq.com/s/ePh8jukhc8KcLXDVu6-CrA](https://mp.weixin.qq.com/s/ePh8jukhc8KcLXDVu6-CrA)
