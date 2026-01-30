# 飞书消息模板

## 文本消息

```json
{"msg_type": "text", "content": {"text": "消息内容"}}
```

## 卡片消息（当前使用）

支持 Markdown 格式，更美观的展示效果。

```json
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {"tag": "plain_text", "content": "标题"},
      "template": "blue"
    },
    "elements": [
      {"tag": "div", "text": {"tag": "lark_md", "content": "内容支持 **Markdown**"}}
    ]
  }
}
```

## 自定义颜色

`header.template` 可选值：
- blue (蓝色，默认)
- wathet (浅蓝)
- turquoise (青色)
- green (绿色)
- yellow (黄色)
- orange (橙色)
- red (红色)
- carmine (洋红)
- violet (紫罗兰)
- purple (紫色)
- indigo (靛青)
- grey (灰色)

## 富文本消息

```json
{
  "msg_type": "post",
  "content": {
    "post": {
      "zh_cn": {
        "title": "标题",
        "content": [
          [{"tag": "text", "text": "内容"}]
        ]
      }
    }
  }
}
```
