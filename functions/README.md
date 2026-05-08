# Firebase Functions 后端接口

## analyzeListing

Callable Function：`analyzeListing`

用途：根据 Firebase Storage 中的商品图片调用 OpenAI 视觉模型，返回商品识别、估价、标题、描述和标签。

### 入参

```json
{
  "imagePaths": [
    "listing_images/{userId}/{listingId}/1_main.jpg"
  ],
  "currency": "GBP",
  "locationLabel": "London / UCL",
  "userConditionHint": "轻微使用"
}
```

### 返回

```json
{
  "analysisId": "firestore_doc_id",
  "category": "数码",
  "brand": "Sony",
  "model": "WH-1000XM5",
  "condition": "轻微使用",
  "estimatedLow": 72,
  "estimatedHigh": 95,
  "suggestedPrice": 88,
  "confidence": 0.86,
  "title": "Sony WH-1000XM5 降噪耳机",
  "description": "功能正常，外观干净，适合通勤和学习使用。",
  "tags": ["降噪耳机", "蓝牙", "学生自用"],
  "reasoningBrief": "根据图片中的型号、成色和英国二手市场常识估算。",
  "warnings": ["图片无法完全确认配件是否齐全"],
  "recognizedItems": [
    {
      "category": "数码",
      "brand": "Sony",
      "model": "WH-1000XM5",
      "condition": "轻微使用",
      "confidence": 0.86,
      "title": "Sony WH-1000XM5 降噪耳机",
      "description": "功能正常，外观干净，适合通勤使用。",
      "tags": ["降噪耳机", "蓝牙"],
      "reasoningBrief": "根据耳罩形状和型号标识判断。",
      "warnings": ["配件需要人工确认"]
    }
  ]
}
```

### 配置密钥

部署前需要设置 OpenAI API Key：

```bash
firebase functions:secrets:set OPENAI_API_KEY --project mobileprojectserver
```

可选：修改默认模型。在 `functions/.env` 或 `functions/.env.mobileprojectserver` 中加入：

```env
OPENAI_LISTING_MODEL=gpt-5-mini
```

当前代码默认读取 Functions 参数 `OPENAI_LISTING_MODEL`，默认值为 `gpt-5-mini`。

### 本地构建

```bash
cd functions
npm install
npm run build
```

### 部署

```bash
firebase deploy --only functions --project mobileprojectserver
```
