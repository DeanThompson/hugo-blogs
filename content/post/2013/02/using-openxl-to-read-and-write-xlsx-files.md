+++
date = "2013-02-25T16:39:55+08:00"
draft = false
tags = ["python", "xlsx", "openpyxl"]
categories = ["python"]
title = "用 openpyxl 处理 xlsx 文件"
slug = "using-openpyxl-to-read-and-write-xlsx-files"
+++

久违的图书馆~~虽然刚开学，图书馆里已经有不少同学在看书自习了，学校的氛围就是不一样，在安静的环境和熟悉的书香中，很容易就静下心来。OK，下面进入正题。

`openpyxl` 是一个用来处理 excel 文件的 python 代码库。Python 有一些内置的功能相似的代码库，不过我都没用过，而且好像都有不少局限性。`openpyxl` 用起来还是挺简单的，对照文档就可以解决一些基本需求，比如常见的都写操作。不过有一个前提，它只能用来处理 Excel 2007 及以上版本的 excel 文件，也就是 `.xlsx/.xlsm` 格式的表格文件。顺便提一下，`xls` 和 `xlsx` 是两种完全不同的格式，其本质的差别相比字面的区别要多很多。xls 的核心结构是复合文档类型的结构，而 xlsx 的核心结构是 XML 类型的结构，采用的是基于XML的压缩方式，使其占用的空间更小。`xlsx` 中最后一个 `x` 的意义就在于此。

<!--more-->

# 1. 安装

可以在这里下载openpyxl的代码包，然后从源代码安装即可。最新版本是 1.6.1.

> [https://pypi.python.org/pypi/openpyxl](https://pypi.python.org/pypi/openpyxl)

# 2. 读

用openpyxl读一个xlsx文件很简单：

```python
from openpyxl import load_workbook
 
wb = load_workbook(filename=r'existing_file.xlsx')
 
sheets = wb.get_sheet_names()   # 获取所有表格(worksheet)的名字
sheet0 = sheets[0]  # 第一个表格的名称
ws = wb.get_sheet_by_name('sheet_name') # 获取特定的 worksheet
 
# 获取表格所有行和列，两者都是可迭代的
rows = ws.rows
columns = ws.columns
 
# 行迭代
content = []
for row in rows:
    line = [col.value for col in row]
    content.append(line)
 
# 通过坐标读取值
print ws.cell('B12').value    # B 表示列，12 表示行
print ws.cell(row=12, column=2).value
```

当调用 `get_sheet_by_name('sheet_name')` 方法获取表格时，如果名字为 `sheet_name` 的表格不存在，不会报错或抛出异常，而只是返回 `None`.

# 3. 写

```python
from openpyxl import Workbook
 
# 在内存中创建一个workbook对象，而且会至少创建一个 worksheet
wb = Workbook()
 
ws = wb.get_active_sheet()
print ws.title
ws.title = 'New Title'  # 设置worksheet的标题
 
# 设置单元格的值
ws.cell('D3').value = 4
ws.cell(row=3, column=1).value = 6
 
new_ws = wb.create_sheet(title='new_sheet')
for row in range(1, 100):
    for col in range(1, 10):
        new_ws.cell(row=row, column=col).value = row+col
 
# 最后一定要保存！
wb.save(filename='new_file.xlsx')
```

# 4. 文档

对于常规的小文件的操作，以上的一些介绍基本是够了。有时候需要处理大文件，就需要用到更高级一些的方法。更详细的用法、教程和API文档请参考这里：

> [http://pythonhosted.org/openpyxl/](http://pythonhosted.org/openpyxl/)


# 5. References

- 下载 openpyxl：[https://pypi.python.org/pypi/openpyxl](https://pypi.python.org/pypi/openpyxl)
- openpyxl 文档：[http://pythonhosted.org/openpyxl/](http://pythonhosted.org/openpyxl/)

