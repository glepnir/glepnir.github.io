+++
title = "Go-使用装饰器模式封装Json的响应"
author = "Raphael Huan"
date = "2020-10-27T19:37:04+08:00"
description = "使用装饰器模式封装Json的响应"
tags = ["Go"]
categories = ["Go"]
images = [""]
+++

## 常见的处理Http Json的响应输出

日常开发处理业务的时候这一步是必不可少的,判断处理各种情况然后返回给前端，有时候需要写不少重复的代码

例如这样的。

```go
func main() {
	e := echo.New()
	e.GET("/user", getUserData)
	e.GET("/article", getArticleData)
	e.Start(":8080")
}

func getUserData(c echo.Context) error {
	return c.JSON(code, "result interface")
}

func getArticleData(c echo.Context) error {
	return c.JSON(code, "article interface")
}
```

上述的例子呢很简单，echo框架写一个http服务这里与框架关系不大，任何框架甚至标准库这里的代码也是大同

小异的，没什么很大的差别。忽略掉业务逻辑只关注return这部分，从目前的代码来看好像看不出什么问题，但

是项目的业务是很多的，这部分代码你可能要重写很多遍。那就做了许多的无用功很低效了，所以优雅的封装这

里是很有必要的，那么方式不止一种这里使用装饰器模式，如果你有其他优雅的方式可以写在评论区一起交流。

## 使用装饰器模式

首先通过观察handler函数同样的参数和返回值,进一步将它抽象定义一个新的类型`myHandler`。

```go
func getArticleData(c echo.Context) error {
	return c.JSON(code, "article interface")
}

type myHandler func(c echo.Context) (int, interface{})

```

那么处理逻辑的函数就会变得更加简单直接

```go
// 业务状态编码: 1000 => success 10001 ==> failed
func getUserHandler(c echo.Context) (int, interface{}) {
	result := map[string]interface{}{
		"msg": "success",
		"data": map[string]interface{}{
			"name": "admin",
			"age":  50,
		},
	}
	return 1000, result
}
```

接下来使用装饰器，将业务逻辑的函数装饰一下。最终的目的是要将这个业务逻辑函数放入到路由里去也就是

`e.Get("/users",装饰后)`,那么这里的第二个参数的类型是`echo.HandlerFunc`,gin框架标准库这里也是类似的

名称，所以装饰过后的东西必然要满足`echo.HandlerFunc`。所以我们返回一个函数参数是我们定义的新类型，

返回值就是`echo.HandlerFunc`,其实这里与写中间件的写法是类似的，无非是多加了一层和定义了一个新的类型

```go
func handler() func(m myHandler) echo.HandlerFunc {
	return func(m myHandler) echo.HandlerFunc {
		return func(c echo.Context) error {
			code, result := m(c)
			if code == 1000 {
				return c.JSON(200, result)
			} else {
				return c.JSON(400, result)
			}
		}
	}
}
```

