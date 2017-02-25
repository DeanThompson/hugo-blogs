+++
date = "2017-02-25T16:16:14+08:00"
draft = false
tags = ["python", "mysql", "multiprocessing"]
categories = ["python", "mysql"]
title = "Python 多进程导入数据到 MySQL"
slug = "load-data-into-mysql-using-python-multiprocessing"
+++

前段时间帮同事处理了一个把 CSV 数据导入到 MySQL 的需求。两个很大的 CSV 文件，
分别有 3GB、2100 万条记录和 7GB、3500 万条记录。对于这个量级的数据，用简单的单进程／单线程导入
会耗时很久，最终用了多进程的方式来实现。具体过程不赘述，记录一下几个要点：

- 批量插入而不是逐条插入
- 为了加快插入速度，先不要建索引
- 生产者和消费者模型，主进程读文件，多个 worker 进程执行插入
- 注意控制 worker 的数量，避免对 MySQL 造成太大的压力
- 注意处理脏数据导致的异常
- 原始数据是 GBK 编码，所以还要注意转换成 UTF-8
- 用 [click](http://click.pocoo.org/5/) 封装命令行工具

具体的代码实现如下：

<!--more-->

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import codecs
import csv
import logging
import multiprocessing
import os
import warnings

import click
import MySQLdb
import sqlalchemy

warnings.filterwarnings('ignore', category=MySQLdb.Warning)

# 批量插入的记录数量
BATCH = 5000

DB_URI = 'mysql://root@localhost:3306/example?charset=utf8'

engine = sqlalchemy.create_engine(DB_URI)


def get_table_cols(table):
    sql = 'SELECT * FROM `{table}` LIMIT 0'.format(table=table)
    res = engine.execute(sql)
    return res.keys()


def insert_many(table, cols, rows, cursor):
    sql = 'INSERT INTO `{table}` ({cols}) VALUES ({marks})'.format(
            table=table,
            cols=', '.join(cols),
            marks=', '.join(['%s'] * len(cols)))
    cursor.execute(sql, *rows)
    logging.info('process %s inserted %s rows into table %s', os.getpid(), len(rows), table)


def insert_worker(table, cols, queue):
    rows = []
    # 每个子进程创建自己的 engine 对象
    cursor = sqlalchemy.create_engine(DB_URI)
    while True:
        row = queue.get()
        if row is None:
            if rows:
                insert_many(table, cols, rows, cursor)
            break

        rows.append(row)
        if len(rows) == BATCH:
            insert_many(table, cols, rows, cursor)
            rows = []


def insert_parallel(table, reader, w=10):
    cols = get_table_cols(table)

    # 数据队列，主进程读文件并往里写数据，worker 进程从队列读数据
    # 注意一下控制队列的大小，避免消费太慢导致堆积太多数据，占用过多内存
    queue = multiprocessing.Queue(maxsize=w*BATCH*2)
    workers = []
    for i in range(w):
        p = multiprocessing.Process(target=insert_worker, args=(table, cols, queue))
        p.start()
        workers.append(p)
        logging.info('starting # %s worker process, pid: %s...', i + 1, p.pid)

    dirty_data_file = './{}_dirty_rows.csv'.format(table)
    xf = open(dirty_data_file, 'w')
    writer = csv.writer(xf, delimiter=reader.dialect.delimiter)

    for line in reader:
        # 记录并跳过脏数据: 键值数量不一致
        if len(line) != len(cols):
            writer.writerow(line)
            continue

        # 把 None 值替换为 'NULL'
        clean_line = [None if x == 'NULL' else x for x in line]

        # 往队列里写数据
        queue.put(tuple(clean_line))
        if reader.line_num % 500000 == 0:
            logging.info('put %s tasks into queue.', reader.line_num)

    xf.close()

    # 给每个 worker 发送任务结束的信号
    logging.info('send close signal to worker processes')
    for i in range(w):
        queue.put(None)

    for p in workers:
        p.join()


def convert_file_to_utf8(f, rv_file=None):
    if not rv_file:
        name, ext = os.path.splitext(f)
        if isinstance(name, unicode):
            name = name.encode('utf8')
        rv_file = '{}_utf8{}'.format(name, ext)
    logging.info('start to process file %s', f)
    with open(f) as infd:
        with open(rv_file, 'w') as outfd:
            lines = []
            loop = 0
            chunck = 200000
            first_line = infd.readline().strip(codecs.BOM_UTF8).strip() + '\n'
            lines.append(first_line)
            for line in infd:
                clean_line = line.decode('gb18030').encode('utf8')
                clean_line = clean_line.rstrip() + '\n'
                lines.append(clean_line)
                if len(lines) == chunck:
                    outfd.writelines(lines)
                    lines = []
                    loop += 1
                    logging.info('processed %s lines.', loop * chunck)

            outfd.writelines(lines)
            logging.info('processed %s lines.', loop * chunck + len(lines))


@click.group()
def cli():
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(name)s - %(message)s')


@cli.command('gbk_to_utf8')
@click.argument('f')
def convert_gbk_to_utf8(f):
    convert_file_to_utf8(f)


@cli.command('load')
@click.option('-t', '--table', required=True, help='表名')
@click.option('-i', '--filename', required=True, help='输入文件')
@click.option('-w', '--workers', default=10, help='worker 数量，默认 10')
def load_fac_day_pro_nos_sal_table(table, filename, workers):
    with open(filename) as fd:
        fd.readline()   # skip header
        reader = csv.reader(fd)
        insert_parallel(table, reader, w=workers)


if __name__ == '__main__':
    cli()
```
