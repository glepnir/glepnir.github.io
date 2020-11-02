+++
title = "Umijs-Request的封装以及使用"
author = "Raphael Huan"
date = "2020-11-02T20:49:05+08:00"
description = "umijs-Request 使用以及封装"
tags = ["react,umijs"]
categories = ["react"]
images = [""]
+++

## Umijs

本文基于 Umijs 3.2.24,关于什么是Umijs就不多赘述了，为什么选择Umijs因为之前断断续

续的看过React的一些教程，而且我不喜欢Vue感觉不符合我的编程思想，我可是贯彻做一件

事就把它做好的信念的人啊，一个Vue文件里又写html有写js css的，完全违背我的思想.

所以就偶尔看看React正好又除了hooks简直不要太简单啊，React的上手难度直接降低了很

多，不过还是不想慢慢的去学React那一大套的东西，直接选了个框架Umijs又是蚂蚁前端的

起码文档什么的能有保证，就试了试。。结果文档这一块跟不上包更新的速度，不过还好挺

简单的整体仔细研究一下也能想明白怎么用。


### umijs-request

Umijs-request是基于fetch上封装的，又加了许多的功能,与fetch axios的对比

| 特性       | umi-request    | fetch          | axios          |
| :--------- | :------------- | :------------- | :------------- |
| 实现       | 浏览器原生支持 | 浏览器原生支持 | XMLHttpRequest |
| 大小       | 9k             | 4k (polyfill)  | 14k            |
| query 简化 | ✅             | ❌             | ✅             |
| post 简化  | ✅             | ❌             | ❌             |
| 超时       | ✅             | ❌             | ✅             |
| 缓存       | ✅             | ❌             | ❌             |
| 错误检查   | ✅             | ❌             | ❌             |
| 错误处理   | ✅             | ❌             | ✅             |
| 拦截器     | ✅             | ❌             | ✅             |
| 前缀       | ✅             | ❌             | ❌             |
| 后缀       | ✅             | ❌             | ❌             |
| 处理 gbk   | ✅             | ❌             | ❌             |
| 中间件     | ✅             | ❌             | ❌             |
| 取消请求   | ✅             | ❌             | ✅             |

功能相当的丰富了。所以我的这个第一个Umijs Crud的Demo直接用了umijs-request没用

axios了，就是配套来吧。


### 基本的封装

`servers/request.ts` 就是我的封装文件了，对于什么utils common等文件夹命名是真的

很讨厌，模糊不清的命名并且任何功能都放在这种命名里显的很混乱源于我曾度过的一本

书Robert Martin的[Agile Software Development, Principles, Patterns, and
Practices](https://www.amazon.co.uk/dp/0135974445/ref=pd_lpo_sbs_dp_ss_2/253-1946330-6751666?pf_rd_m=A3P5ROKL5A1OLE&pf_rd_s=lpo-top-stripe&pf_rd_r=23C4AHYV7EXGYHKD6G8Q&pf_rd_t=201&pf_rd_p=569136327&pf_rd_i=0132760584)

定义一些常用的http状态码的返回消息

```typescript
import { extend } from 'umi-request'
import { notification } from 'antd'

type CodeMsg = {
  [key: number]: string
}

const codeMessage: CodeMsg = {
  200: '服务器成功返回请求的数据。',
  201: '新建或修改数据成功。',
  202: '一个请求已经进入后台排队（异步任务）。',
  204: '删除数据成功。',
  400: '发出的请求有错误，服务器没有进行新建或修改数据的操作。',
  401: '用户没有权限（令牌、用户名、密码错误）。',
  403: '用户得到授权，但是访问是被禁止的。',
  404: '发出的请求针对的是不存在的记录，服务器没有进行操作。',
  406: '请求的格式不可得。',
  410: '请求的资源被永久删除，且不会再得到的。',
  422: '当创建一个对象时，发生一个验证错误。',
  500: '服务器发生错误，请检查服务器。',
  502: '网关错误。',
  503: '服务不可用，服务器暂时过载或维护。',
  504: '网关超时。',
};

```

全局的错误处理器函数，只需要判断response有没有值即可

```typescript

const errorHandler = (error: { response: Response }): Response => {
  const { response } = error
  if (response && response.status) {
    const errorText = codeMessage[response.status] || response.statusText
    const { status, url } = response

    notification.error({
      message: `请求错误 ${status}:${url}`,
      description: errorText,
    })
  } else if (!response) {
    notification.error({
      description: '网络发生异常 无法连接服务器',
      message: '网络发生异常'
    })
  }
  return response
}

```
其实这里还可以进行更细粒度的处理，例如判断`status` 的值也就是http状态码，例如404

跳转到404页面 或者401 等等,可以从umi中 引`history`进行一些路由的跳转处理
```typescript
if (status === 401) {
    notification.error({
      message: `登录已过期，请重新登录`,
      duration: 2,
    });
    history.push('/')
    return
  }

```

从umi中引入`extend`实例化一个request，当然这里变量名可以是任意的如果想区分一下可以

叫`HttpRequest` 等。字段的说明[文档](https://github.com/umijs/umi-request/blob/master/README_zh-CN.md#%E8%AF%B7%E6%B1%82%E9%85%8D%E7%BD%AE)

```typescript

const request = extend({
  prefix: '/api/',
  timeout: 15000,
  errorHandler,
  credentials: 'include' -- 是否携带cookie  include为携带
})

```

定义请求的拦截器，这里是简单的版本实际上jwt的token直接存到`localStorage`里是不

安全的存在xss攻击等可能性，存在cookie呢又会有一些Csrf攻击的问题，所以一种办法

是将token拆成三部分分开存，在请求的时候可以在这里进行合并然后放到`Authorization`

里
```typescript

request.interceptors.request.use((url, options) => {
  const token = localStorage.getItem('xxx-token')
  if (token) {
    const headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': token,
    }
    return { url, options: { ...options, headers } }
  }
  return { url, options }
})

```
响应的拦截器就是通过判断后端传的`code`参数一般是业务逻辑的状态码
```typescript

request.interceptors.response.use(async response => {
  const res = await response.clone().json()
  if (res.code === 1000) {
    return response
  } else {
    notification.error({
      description: res.msg || '网络发生异常无法连接服务器',
      message: '请求错误',
    })
    return response
  }
})

export default request
```

### 使用

例如请求一个课程的Demo `services/courseApi.ts`

```typescript
export default async function fetchCourseList(keywords: string) {
  const res = await request('courseList', {
    method: 'get', params: { keywords }
  })
  return res
}

```

使用`async/await`的写法实际上就是`yield/next`，typescript异步协程这里用的是libuv

之前写过一些lua所以比较lua 的coroutine和libuv这里上手也比较简单。在组件中使用

```typescript
  const getDatas = async (keywords: string) => {
    const res = await fetchCourseList(keywords);
    if (res) {
      setDatas(res.datas);
    }
  };

  useEffect(() => {
    getDatas(keywords);
  }, []);
```

异步判断返回值如果有就调用useState提供的设置值的方法把数据传进去即可。总体来说

我是大概看了几天就能上手了还是挺方便我们这些后端开发的。可能这篇文章没什么深度

因为我对前端这块也就是偶尔看两眼现用先看的样子。理解的不够到位。作为个记录把
