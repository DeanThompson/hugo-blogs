---
title: "AWS S3 Bucket 指定权限"
date: 2019-10-23T10:53:00+08:00
draft: false
slug: "aws-s3-bucket-policy"
categories: ["aws"]
tags: ["aws", "s3"]
---

有时候需要通过 S3 给外部用户交付数据，可通过这种方式实现：创建一个新的 IAM 用户和 S3 bucket，给该用户赋予对应的读写权限。

## 创建 IAM 用户

创建新的 IAM 用户，不赋予任何权限，生成 access key. 假设新用户的 ARN 是 `arn:aws-cn:iam::123456789012:user/exampleuser`.

## 配置 S3 bucket 权限

创建 S3 bucket，假设名字为 `example-bucket`，于是对应的 ARN 为 `arn:aws-cn:s3:::example-bucket `. 进入 Permissions 页面，编辑 Bucket Policy.

<!--more-->

```json
{
    "Version": "2012-10-17",
    "Id": "Policy1571646921804",
    "Statement": [
        {
            "Sid": "Stmt1571646903119",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws-cn:iam::123456789012:user/exampleuser"
            },
            "Action": "s3:ListBucket",
            "Resource": "arn:aws-cn:s3:::example-bucket"
        },
        {
            "Sid": "Stmt1571646919492",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws-cn:iam::123456789012:user/exampleuser"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws-cn:s3:::example-bucket/*"
        }
    ]
}
```

这里分配了 `s3:ListBucket` 和 `s3:GetObject` 两个权限，即可以列出及读取  bucket  里所有对象。要注意 `s3:ListBucket` 是 bucket 级别的，所以 `Resource` 就是 bucket 的 ARN；`s3:GetObject` 是对象级别的，所以 `Resource` 最后要加上 `/*`.

Bucket Policy 可以通过 [Policy generator](https://awspolicygen.s3.cn-north-1.amazonaws.com.cn/policygen.html) 生成。添加 2 个 Statement，如下图所示

![s3_bucket_policy_generator.png](https://i.loli.net/2019/10/23/KAr2RdmwGLEUbyX.png)

点击 Generate Policy 即可生成 JSON 格式的 policy.

## 测试

用 `aws` 命令行程序测试（安装：`pip install awscli`）。先配置好 access key 和 region 信息。

```
$ aws s3 ls

An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied

$ aws s3 ls example-bucket
                           PRE data/
2019-10-21 16:40:49          7 test.txt

$ aws s3 cp s3://example-bucket/test.txt .
download: s3://example-bucket/test.txt to ./test.txt

$ aws s3 rm s3://example-bucket/test.txt
delete failed: s3://example-bucket/test.txt An error occurred (AccessDenied) when calling the DeleteObject operation: Access Denied
```
