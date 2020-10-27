+++
title = "¿¿¿¿¿¿¿¿¿Json¿¿¿"
author = "Raphael Huan"
date = "2020-10-27T19:37:04+08:00"
description = "¿¿¿¿¿¿¿¿¿Json¿¿¿"
tags = ["Go"]
categories = ["Go"]
images = [""]
+++

## ¿¿¿¿¿Http Json¿¿¿¿¿

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿,¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

¿¿¿¿¿¿

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

¿¿¿¿¿¿¿¿¿¿echo¿¿¿¿¿http¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿return¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

## ¿¿¿¿¿¿¿

¿¿¿¿¿¿handler¿¿¿¿¿¿¿¿¿¿¿,¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿`myHandler`¿

```go
func getArticleData(c echo.Context) error {
	return c.JSON(code, "article interface")
}

type myHandler func(c echo.Context) (int, interface{})

```

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

```go
// ¿¿¿¿¿¿: 1000 => success 10001 ==> failed
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

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

`e.Get("/users",¿¿¿)`,¿¿¿¿¿¿¿¿¿¿¿¿¿¿`echo.HandlerFunc`,gin¿¿¿¿¿¿¿¿¿¿¿¿

¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿`echo.HandlerFunc`¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

¿¿¿¿¿`echo.HandlerFunc`,¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿

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

