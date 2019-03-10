+++
date = "2019-03-10T22:24:51+08:00"
title = "字节跳动（今日头条） 2018 校招后端第二批算法题"
draft = false
slug = "2018-holiday"
categories = ["devops"]
tags = ["algorithm", "go"]
+++

逛 V2EX 的时候无意间看到了有个叫 [牛客网](https://www.nowcoder.com) 的网站，里面有很多公司的笔试真题和大家分享的面经。
出于好奇，看了一下 [字节跳动（今日头条）的后端题](https://www.nowcoder.com/test/8537209/summary)。

一共有 5 题，3 道编程，2 道问答。时候发现前面 4 题跟算法有关，其中 3 道要实现，1 道是纠错和优化，最后一题是系统设计。
做得比较差，只完成了前面两道算法题。用 Go 语言实现，代码如下。

<!--more-->

## 用户喜好

### 问题

> 为了不断优化推荐效果，今日头条每天要存储和处理海量数据。假设有这样一种场景：我们对用户按照它们的注册时间先后来标号，对于一类文章，每个用户都有不同的喜好值，我们会想知道某一段时间内注册的用户（标号相连的一批用户）中，有多少用户对这类文章喜好值为k。因为一些特殊的原因，不会出现一个查询的用户区间完全覆盖另一个查询的用户区间(不存在L1<=L2<=R2<=R1)。

> 输入描述:

>> 输入： 第1行为n代表用户的个数 第2行为n个整数，第i个代表用户标号为i的用户对某类文章的喜好度 第3行为一个正整数q代表查询的组数  第4行到第（3+q）行，每行包含3个整数l,r,k代表一组查询，即标号为l<=i<=r的用户中对这类文章喜好值为k的用户的个数。 数据范围n <= 300000,q<=300000 k是整型

> 输出描述:

>> 输出：一共q行，每行一个整数代表喜好值为k的用户的个数

### 分析

把题目转换成程序语言来描述就是，给定长度为 `n` 的 `int` 数组，查找指定下标范围 `[l, r]` 内，值为 `k` 的元素数量。

一种算法是遍历数组`[l, r]`，统计值为 `k` 的数量。

另外就是可以构建哈希表，以元素值为键，对应的下标（构成数组）为值。查找时快速取出所有的下标，统计 `[l, r]` 的下标数量。
提交的是这种算法，代码如下。运行通过，耗时 2688ms, 内存 9560K, 险些超时。
后来网上搜了一下，查找 `l` 和 `r` 对应的下标可以使用二分查找算法，效率更高。

### 代码

```go
package main

import "fmt"

func main() {
	var n, q, l, r, k int
	_, _ = fmt.Scan(&n)

	table := make(map[int][]int)
	var v int
	for i := 0; i < n; i++ {
		_, _ = fmt.Scan(&v)
		indexes, ok := table[v]
		if !ok {
			indexes = make([]int, 0)
			table[v] = indexes
		}
		table[v] = append(indexes, i+1)
	}

	_, _ = fmt.Scan(&q)
	for i := 0; i < q; i++ {
		_, _ = fmt.Scan(&l, &r, &k)
		count := 0
		if indexes, ok := table[k]; ok {
			for _, idx := range indexes {
				if l <= idx && idx <= r {
					count++
				}
				// 下标数组是有序的，如果到了 r 说明后面的都不符合条件，可以退出循环
				if idx > r {
					break
				}
			}
		}
		fmt.Println(count)
	}
}
```

## 手串

### 问题

时间限制：1秒 空间限制：65536K

> 作为一个手串艺人，有金主向你订购了一条包含n个杂色串珠的手串——每个串珠要么无色，要么涂了若干种颜色。为了使手串的色彩看起来不那么单调，金主要求，手串上的任意一种颜色（不包含无色），在任意连续的m个串珠里至多出现一次（注意这里手串是一个环形）。手串上的颜色一共有c种。现在按顺时针序告诉你n个串珠的手串上，每个串珠用所包含的颜色分别有哪些。请你判断该手串上有多少种颜色不符合要求。即询问有多少种颜色在任意连续m个串珠中出现了至少两次。

> 输入描述:

>> 第一行输入n，m，c三个数，用空格隔开。(1 <= n <= 10000, 1 <= m <= 1000, 1 <= c <= 50) 接下来n行每行的第一个数num_i(0 <= num_i <= c)表示第i颗珠子有多少种颜色。接下来依次读入num_i个数字，每个数字x表示第i颗柱子上包含第x种颜色(1 <= x <= c)

> 输出描述:

>> 一个非负整数，表示该手链上有多少种颜色不符需求。

### 分析

跟第一题类似，也是构建哈希表，记录每种颜色出现过的位置（是个数组）。迭代这个数组，如果出现相邻两个元素差值小于 `m`，就不符合需求。
需要注意的是最后一个元素，判断是否「套圈」。代码如下，运行时间 57ms, 内存 1892K.

### 代码

```go
package main

import "fmt"

func main() {
	var n, m, c int
	_, _ = fmt.Scanln(&n, &m, &c)

	colorIndexes := make(map[int][]int, c)
	for i := 0; i < n; i++ {
		var colorCount int
		_, _ = fmt.Scan(&colorCount)

		for j := 0; j < colorCount; j++ {
			var color int
			_, _ = fmt.Scan(&color)
			indexes, ok := colorIndexes[color]
			if !ok {
				indexes = make([]int, 0)
				colorIndexes[color] = indexes
			}
			colorIndexes[color] = append(colorIndexes[color], i+1)
		}
	}

	result := 0
	for _, indexes := range colorIndexes {
		if len(indexes) <= 1 {
			continue
		}
		for i := 0; i < len(indexes); i++ {
			if i == len(indexes)-1 {
				if (indexes[i]+m)%n > indexes[0] {
					result++
					break
				}
			} else if indexes[i]+m > indexes[i+1] {
				result++
				break
			}
		}
	}
	fmt.Println(result)
}
```

## 总结

1. 第三题没做出来，是个动态规划问题，没训练过。动态规划算法题很常见，可以学习一下。
2. 临时查了一下 Go 从 stdin 读取变量的方法。刚开始用了 `bufio.Reader`，手动读入字符串、切分、转换成 int，特别蛋疼，而且效率很低。
3. 总体来说，对算法还是很不熟悉。比如第一题没想到用二分查找。这还是天然有序的，如果要自己排序，手写快排估计也够呛（不过可以用标准库...）。
