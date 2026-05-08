# 闲置估价交易平台后端配套需求文档

版本：v0.1  
对应前端：Flutter 原型，已包含用户系统、商品发布、交易市场、商品详情、地图位置、收藏点赞、买卖家聊天  
推荐后端方向：Firebase Auth + Firestore + Firebase Storage + Cloud Functions/自建 AI API
地图服务：Mapbox Maps SDK for Flutter + Firestore 经纬度字段

## 1. 产品目标

本 App 的核心目标是降低用户出售闲置物品的门槛：

- 拍照或上传图片后识别商品信息。
- AI 预估合理售价。
- AI 生成标题、描述、标签。
- 用户确认后发布到二手交易市场。
- 买家浏览、收藏、点赞、查看位置、联系卖家。
- 买卖双方围绕商品进行聊天，后续可扩展到下单、支付、评价。

后端需要支持两类核心链路：

- 卖家链路：注册登录 -> 上传图片 -> AI 分析 -> 编辑商品信息 -> 发布商品 -> 回复买家咨询。
- 买家链路：浏览/搜索/筛选商品 -> 查看详情和地点 -> 收藏/点赞 -> 联系卖家 -> 下单/评价，订单模块可后续实现。

## 2. 当前前端页面与后端能力映射

| 前端模块 | 页面 | 后端需要支持 |
| --- | --- | --- |
| 用户系统 | 登录页、注册页、忘记密码页 | 手机号/邮箱/Google 登录，验证码，密码重置，Token 校验 |
| 个人中心 | 个人中心页、编辑资料页 | 用户资料、头像、手机号、邮箱、校园/地区、信用分、交易评分 |
| 地址管理 | 地址管理页 | 地址 CRUD、默认地址、手机号、地区、详细地址 |
| 商品发布 | 发布入口页、拍照页、图片预览页、商品信息编辑页、AI 估价结果页、发布成功页 | 图片上传、图片压缩后存储、AI 图片识别、AI 估价、草稿保存、正式发布 |
| 商品市场 | 首页、分类页、搜索页、筛选弹窗、商品详情页、收藏夹页 | 推荐流、分类、搜索、筛选、商品详情、浏览记录、收藏、点赞 |
| 地图位置 | 发布地点地图页 | 商品发布位置、经纬度/模糊位置、附近商品 |
| 聊天系统 | 消息列表页、聊天详情页 | Firebase 实时会话、消息发送、未读数、图片消息、FCM 推送 |
| 后续交易 | 订单、支付、确认收货、评价 | 订单状态机、支付状态、评价、交易评分 |

## 3. 推荐技术架构

MVP 建议使用 Firebase 为主，AI 部分使用 Cloud Functions 或独立后端服务承接。

### 3.1 Firebase 组件

- Firebase Authentication：手机号、邮箱、Google 登录。
- Cloud Firestore：用户、商品、收藏、点赞、聊天、订单等实时数据。
- Firebase Storage：商品图片、用户头像、聊天图片。
- Firebase Cloud Messaging：聊天消息、订单状态、商品咨询推送。
- Cloud Functions：敏感操作、计数器、AI 服务代理、定时任务。

### 3.2 AI 服务组件

AI 不建议由 Flutter 直接调用。推荐：

- Flutter 上传图片到 Firebase Storage。
- Flutter 调用后端 `POST /ai/listing-analysis`。
- 后端读取图片 URL 或 Storage 路径。
- 后端调用视觉模型/LLM。
- 后端结合相似商品成交记录给出价格区间。
- 后端返回结构化 JSON 给 Flutter。

### 3.3 地图服务组件

当前前端已接入 Mapbox Flutter SDK。后端不需要直接渲染地图，但需要为商品提供可查询的位置数据：

- 商品发布时保存 `locationLabel` 和 `geo.lat/lng`。
- 推荐流、搜索、筛选接口返回商品的展示位置标签。
- 附近商品查询建议基于 `geohash` 或地理索引实现。
- 对外展示建议使用模糊位置，例如校园、街区或 300 米半径，避免直接暴露卖家精确住址。

## 4. 权限与登录

### 4.1 支持登录方式

- 手机号验证码登录/注册。
- 邮箱密码登录/注册。
- Google OAuth 登录。
- 忘记密码：邮箱重置或手机号验证码重置。

### 4.2 用户身份

所有需要写入数据的接口都必须校验 Firebase ID Token。

匿名可访问：

- 商品推荐流。
- 商品详情。
- 分类和搜索。

登录后可访问：

- 发布商品。
- 收藏、点赞、浏览记录。
- 联系卖家。
- 发送消息。
- 管理地址。
- 编辑资料。
- 下单、评价。

## 5. Firestore 数据模型建议

字段命名建议使用 camelCase。时间字段统一使用 server timestamp。金额字段建议用整数，单位为便士 `pence`，避免浮点误差。例如 `8800` 表示 `£88.00`。

### 5.1 users

路径：`users/{userId}`

```json
{
  "userId": "uid_123",
  "displayName": "Yifan",
  "avatarUrl": "https://...",
  "avatarLabel": "YF",
  "bio": "校园数码与摄影器材卖家",
  "campus": "UCL",
  "locationLabel": "UCL 附近",
  "phoneVerified": true,
  "emailVerified": true,
  "googleLinked": true,
  "creditScore": 98,
  "rating": 4.9,
  "reviewCount": 126,
  "soldCount": 42,
  "activeListingCount": 12,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

注意：

- 手机号、邮箱等隐私字段可以拆到 `userPrivate/{userId}`，避免被普通商品查询读到。
- `creditScore` 和 `rating` 应由后端计算，不允许客户端直接写。

### 5.2 addresses

路径：`users/{userId}/addresses/{addressId}`

```json
{
  "addressId": "addr_123",
  "name": "Yifan",
  "phone": "13800138000",
  "region": "London",
  "detail": "UCL Main Campus",
  "tag": "默认",
  "isDefault": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

规则：

- 每个用户最多建议 20 个地址。
- 设置默认地址时，后端需要保证同一用户只有一个默认地址。

### 5.3 listings

路径：`listings/{listingId}`

```json
{
  "listingId": "listing_123",
  "sellerId": "uid_seller",
  "title": "Sony WH-1000XM5 降噪耳机",
  "description": "外观干净，功能正常，适合通勤和学习使用。",
  "category": "数码",
  "brand": "Sony",
  "model": "WH-1000XM5",
  "condition": "lightly_used",
  "conditionLabel": "轻微使用",
  "pricePence": 8800,
  "currency": "GBP",
  "tags": ["降噪耳机", "蓝牙", "学生自用"],
  "imageUrls": ["https://..."],
  "coverImageUrl": "https://...",
  "locationLabel": "UCL 附近",
  "geo": {
    "lat": 51.5246,
    "lng": -0.1340,
    "geohash": "gcpvj..."
  },
  "mapDisplay": {
    "mode": "approximate",
    "radiusMeters": 300
  },
  "status": "active",
  "viewCount": 248,
  "likeCount": 37,
  "favoriteCount": 12,
  "ai": {
    "estimatedLowPence": 7200,
    "estimatedHighPence": 9500,
    "suggestedPricePence": 8800,
    "confidence": 92,
    "analysisId": "analysis_123"
  },
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "publishedAt": "timestamp"
}
```

状态枚举：

- `draft`：草稿。
- `analyzing`：AI 分析中。
- `active`：已发布。
- `reserved`：已预留。
- `sold`：已售出。
- `removed`：卖家下架。
- `blocked`：平台风控下架。

成色枚举：

- `new`：全新。
- `like_new`：几乎全新。
- `lightly_used`：轻微使用。
- `heavily_used`：明显使用。

### 5.4 listingInteractions

路径：`listingInteractions/{listingId}_{userId}`

```json
{
  "listingId": "listing_123",
  "userId": "uid_123",
  "isFavorite": true,
  "isLiked": true,
  "viewedAt": "timestamp",
  "favoritedAt": "timestamp",
  "likedAt": "timestamp"
}
```

说明：

- 前端现在有收藏、点赞、浏览数。
- 计数器建议由 Cloud Functions 或事务维护，避免客户端篡改 `likeCount`。

### 5.5 conversations

路径：`conversations/{conversationId}`

```json
{
  "conversationId": "listing_listing_123_uid_buyer",
  "listingId": "listing_123",
  "listingSnapshot": {
    "title": "Sony WH-1000XM5 降噪耳机",
    "pricePence": 8800,
    "currency": "GBP",
    "coverImageUrl": "https://...",
    "conditionLabel": "轻微使用",
    "locationLabel": "UCL 附近"
  },
  "buyerId": "uid_buyer",
  "sellerId": "uid_seller",
  "participantIds": ["uid_buyer", "uid_seller"],
  "lastMessage": {
    "text": "可以 £80 今天 UCL 自提吗？",
    "senderId": "uid_buyer",
    "kind": "text",
    "sentAt": "timestamp"
  },
  "unreadCounts": {
    "uid_buyer": 0,
    "uid_seller": 1
  },
  "status": "consulting",
  "statusLabel": "买家询价",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

状态枚举：

- `consulting`：咨询中。
- `offer_sent`：已出价。
- `meeting_pending`：待确认面交时间。
- `order_created`：已生成订单。
- `closed`：会话关闭。

### 5.6 messages

路径：`conversations/{conversationId}/messages/{messageId}`

```json
{
  "messageId": "msg_123",
  "conversationId": "listing_listing_123_uid_buyer",
  "senderId": "uid_buyer",
  "text": "你好，请问最低可以多少？配件都还在吗？",
  "kind": "text",
  "imageUrl": null,
  "offer": null,
  "isDeleted": false,
  "createdAt": "timestamp",
  "readBy": {
    "uid_buyer": "timestamp"
  }
}
```

消息类型：

- `text`：普通文字。
- `image`：图片消息，图片存储在 Firebase Storage。
- `offer`：出价消息。
- `system`：系统提醒。

### 5.7 aiAnalyses

路径：`aiAnalyses/{analysisId}`

```json
{
  "analysisId": "analysis_123",
  "userId": "uid_123",
  "listingDraftId": "draft_123",
  "imageUrls": ["https://..."],
  "status": "completed",
  "category": "数码",
  "brand": "Sony",
  "model": "WH-1000XM5",
  "condition": "lightly_used",
  "estimatedLowPence": 7200,
  "estimatedHighPence": 9500,
  "suggestedPricePence": 8800,
  "confidence": 92,
  "title": "Sony WH-1000XM5 降噪耳机",
  "description": "外观干净，功能正常，适合通勤和学习使用。",
  "tags": ["降噪耳机", "蓝牙", "学生自用"],
  "similarListings": [
    {
      "title": "Sony XM5 二手耳机",
      "pricePence": 8200,
      "status": "sold"
    }
  ],
  "rawModelOutputPath": "ai-logs/analysis_123.json",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

状态枚举：

- `queued`
- `processing`
- `completed`
- `failed`

### 5.8 orders 后续预留

路径：`orders/{orderId}`

```json
{
  "orderId": "order_123",
  "listingId": "listing_123",
  "buyerId": "uid_buyer",
  "sellerId": "uid_seller",
  "pricePence": 8800,
  "currency": "GBP",
  "status": "pending_payment",
  "deliveryMethod": "meetup",
  "addressId": null,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

订单状态：

- `pending_payment`
- `paid`
- `shipped`
- `meetup_pending`
- `received`
- `completed`
- `cancelled`
- `refunded`

## 6. Storage 路径建议

商品图片：

```text
listings/{sellerId}/{listingId}/{imageId}.jpg
```

用户头像：

```text
users/{userId}/avatar.jpg
```

聊天图片：

```text
conversations/{conversationId}/{messageId}.jpg
```

AI 原始输出日志：

```text
ai-logs/{analysisId}.json
```

上传限制：

- 商品图片最多 9 张。
- 单张压缩后建议小于 2 MB。
- 支持 jpg、jpeg、png、heic。
- 服务端需要做 MIME 校验和大小校验。

## 7. API 设计建议

如果完全使用 Firebase SDK，部分读写可以由 Flutter 直接访问 Firestore。但以下操作建议必须通过后端 API 或 Cloud Functions。

### 7.1 认证相关

#### POST /auth/session

用途：客户端用 Firebase ID Token 换取后端会话，或让后端校验当前用户。

请求：

```json
{
  "firebaseIdToken": "eyJhbGciOi..."
}
```

响应：

```json
{
  "userId": "uid_123",
  "isNewUser": false,
  "profileCompleted": true
}
```

### 7.2 AI 商品识别与估价

#### POST /ai/listing-analysis

用途：根据商品图片识别类别、品牌、型号、成色，生成价格区间、标题、描述和标签。

请求：

```json
{
  "draftId": "draft_123",
  "imageUrls": ["https://..."],
  "userHints": {
    "category": "数码",
    "brand": "",
    "model": "",
    "condition": ""
  },
  "currency": "GBP",
  "location": {
    "lat": 51.5246,
    "lng": -0.1340
  }
}
```

响应：

```json
{
  "analysisId": "analysis_123",
  "status": "completed",
  "category": "数码",
  "brand": "Sony",
  "model": "WH-1000XM5",
  "condition": "lightly_used",
  "conditionLabel": "轻微使用",
  "estimatedLowPence": 7200,
  "estimatedHighPence": 9500,
  "suggestedPricePence": 8800,
  "confidence": 92,
  "title": "Sony WH-1000XM5 降噪耳机",
  "description": "外观干净，功能正常，适合通勤和学习使用。支持降噪、蓝牙连接，附带收纳盒。",
  "tags": ["降噪耳机", "蓝牙", "学生自用"],
  "warnings": []
}
```

价格估算要求：

- 不要只依赖 LLM 猜价格。
- 需要结合相似在售商品、已成交商品、品牌、型号、成色、地区和时间衰减。
- 返回 `confidence`，低于 60 时前端应提示用户手动确认。
- 对高价值商品可以返回 `warnings`，提示验货、防诈骗或建议人工复核。

### 7.3 发布商品

#### POST /listings

用途：创建正式商品。

请求：

```json
{
  "draftId": "draft_123",
  "analysisId": "analysis_123",
  "title": "Sony WH-1000XM5 降噪耳机",
  "description": "外观干净，功能正常，适合通勤和学习使用。",
  "category": "数码",
  "brand": "Sony",
  "model": "WH-1000XM5",
  "condition": "lightly_used",
  "pricePence": 8800,
  "currency": "GBP",
  "tags": ["降噪耳机", "蓝牙", "学生自用"],
  "imageUrls": ["https://..."],
  "location": {
    "label": "UCL 附近",
    "lat": 51.5246,
    "lng": -0.1340,
    "displayMode": "approximate"
  }
}
```

响应：

```json
{
  "listingId": "listing_123",
  "status": "active",
  "publishedAt": "timestamp"
}
```

校验：

- 标题 5 到 80 字。
- 描述 10 到 1000 字。
- 价格必须大于 0。
- 至少 1 张图片。
- 卖家必须登录。

### 7.4 商品推荐流

#### GET /listings/feed

查询参数：

```text
category=数码
maxPricePence=20000
distanceKm=5
condition=lightly_used
brand=Sony
lat=51.5246
lng=-0.1340
cursor=xxx
limit=20
```

响应：

```json
{
  "items": [
    {
      "listingId": "listing_123",
      "title": "Sony WH-1000XM5 降噪耳机",
      "category": "数码",
      "brand": "Sony",
      "model": "WH-1000XM5",
      "conditionLabel": "轻微使用",
      "pricePence": 8800,
      "currency": "GBP",
      "distanceKm": 1.2,
      "sellerName": "Yifan",
      "locationLabel": "UCL 附近",
      "coverImageUrl": "https://...",
      "viewCount": 248,
      "likeCount": 37,
      "isFavorite": true
    }
  ],
  "nextCursor": "xxx"
}
```

排序建议：

- 距离。
- 发布时间。
- 热度。
- 卖家信用。
- 商品质量分。

### 7.5 商品搜索

#### GET /listings/search

查询参数：

```text
q=耳机
category=数码
maxPricePence=20000
distanceKm=5
condition=lightly_used
brand=Sony
cursor=xxx
limit=20
```

建议：

- MVP 可以使用 Firestore 简单查询。
- 如果要做更好的搜索体验，建议接 Algolia、Meilisearch 或 Typesense。
- 搜索字段至少包含：标题、品牌、型号、分类、标签。

### 7.6 商品详情

#### GET /listings/{listingId}

响应：

```json
{
  "listingId": "listing_123",
  "title": "Sony WH-1000XM5 降噪耳机",
  "description": "功能正常，外观干净，耳罩状态好。",
  "category": "数码",
  "brand": "Sony",
  "model": "WH-1000XM5",
  "conditionLabel": "轻微使用",
  "pricePence": 8800,
  "currency": "GBP",
  "imageUrls": ["https://..."],
  "seller": {
    "sellerId": "uid_seller",
    "name": "Yifan",
    "avatarUrl": "https://...",
    "creditScore": 98,
    "rating": 4.9,
    "reviewCount": 126
  },
  "location": {
    "label": "UCL 附近",
    "lat": 51.5246,
    "lng": -0.1340,
    "displayMode": "approximate",
    "radiusMeters": 300
  },
  "viewCount": 249,
  "likeCount": 37,
  "isFavorite": false,
  "isLiked": false,
  "status": "active"
}
```

访问详情时：

- 后端应记录浏览事件。
- 浏览数应做防刷，例如同一用户/设备短时间只计一次。

### 7.7 收藏与点赞

#### POST /listings/{listingId}/favorite

请求：

```json
{
  "isFavorite": true
}
```

#### POST /listings/{listingId}/like

请求：

```json
{
  "isLiked": true
}
```

要求：

- 必须登录。
- 使用事务更新 `listingInteractions` 和商品计数。
- 同一用户重复点赞不应重复增加计数。

### 7.8 地图商品

#### GET /listings/nearby

查询参数：

```text
lat=51.5246
lng=-0.1340
radiusKm=5
category=数码
limit=50
```

响应：

```json
{
  "items": [
    {
      "listingId": "listing_123",
      "title": "Sony WH-1000XM5 降噪耳机",
      "pricePence": 8800,
      "currency": "GBP",
      "coverImageUrl": "https://...",
      "locationLabel": "UCL 附近",
      "lat": 51.5246,
      "lng": -0.1340,
      "distanceKm": 1.2
    }
  ]
}
```

隐私要求：

- 默认返回模糊位置，不直接暴露卖家精确住址。
- 商品详情可展示区域级位置，例如 “UCL 附近”。
- 只有订单确认后，才考虑展示更精确的自提点。

### 7.9 聊天会话

#### POST /conversations

用途：买家点击商品详情页 “联系卖家” 时创建或获取已有会话。

请求：

```json
{
  "listingId": "listing_123"
}
```

响应：

```json
{
  "conversationId": "listing_listing_123_uid_buyer",
  "created": false
}
```

规则：

- 买家不能给自己发布的商品创建买家会话。
- 同一个买家和同一个商品只能有一个会话。
- 创建会话时写入商品快照，避免商品下架后聊天列表无法展示。

#### Firestore 实时监听

消息列表页监听：

```text
conversations where participantIds array-contains currentUserId order by updatedAt desc
```

聊天详情页监听：

```text
conversations/{conversationId}/messages order by createdAt asc limit 50
```

发送消息：

```text
add document to conversations/{conversationId}/messages
update conversations/{conversationId}.lastMessage
update conversations/{conversationId}.unreadCounts
```

这些写入建议通过 Cloud Function 或后端 API 包一层，以便统一风控和推送。

### 7.10 聊天图片

流程：

1. 客户端选择图片。
2. 上传到 `conversations/{conversationId}/{messageId}.jpg`。
3. 写入 message，`kind=image`，`imageUrl` 为 Storage 下载地址。
4. Cloud Function 发送 FCM 推送。

### 7.11 用户资料

#### PATCH /users/me

请求：

```json
{
  "displayName": "Yifan",
  "bio": "校园数码与摄影器材卖家",
  "campus": "UCL",
  "avatarUrl": "https://..."
}
```

响应：

```json
{
  "userId": "uid_123",
  "displayName": "Yifan",
  "updatedAt": "timestamp"
}
```

### 7.12 地址管理

#### GET /users/me/addresses

#### POST /users/me/addresses

#### PATCH /users/me/addresses/{addressId}

#### DELETE /users/me/addresses/{addressId}

#### POST /users/me/addresses/{addressId}/set-default

要求：

- 地址只能本人读写。
- 删除默认地址后，如果仍有地址，后端应自动选择一个新默认地址。

## 8. Firebase Security Rules 核心要求

### 8.1 users

- 用户可以读取公开资料。
- 用户只能修改自己的基本资料。
- 信用分、评分、成交数只能由后端服务账号更新。

### 8.2 listings

- 所有人可以读取 `active` 商品。
- 卖家可以创建自己的商品。
- 卖家只能编辑自己的商品。
- 普通客户端不能直接写 `viewCount`、`likeCount`、`favoriteCount`。

### 8.3 conversations

- 只有 `participantIds` 包含当前用户时，才可以读取会话。
- 只有会话参与者可以发送消息。
- 消息创建后不允许普通用户修改内容，只允许软删除或撤回。

### 8.4 Storage

- 商品图片只能由商品卖家上传。
- 聊天图片只能由会话参与者上传。
- 文件大小和 MIME 类型必须限制。

## 9. 推送通知

需要接入 FCM Token：

路径：`users/{userId}/devices/{deviceId}`

```json
{
  "deviceId": "ios_device_123",
  "fcmToken": "token",
  "platform": "ios",
  "enabled": true,
  "updatedAt": "timestamp"
}
```

推送场景：

- 收到新聊天消息。
- 有买家咨询自己的商品。
- 商品 AI 分析完成。
- 商品被收藏/点赞，可选。
- 订单状态变化，后续。

## 10. 风控与安全

需要后端处理：

- 图片内容审核，避免违规图片。
- 文本内容审核，覆盖商品标题、描述、聊天消息。
- 高频发布限制。
- 高频消息限制。
- 高频点赞/收藏限制。
- 高价商品或低置信度 AI 估价提示人工复核。
- 举报商品和举报用户能力，后续可加。

## 11. 错误码建议

| code | 含义 |
| --- | --- |
| `UNAUTHENTICATED` | 未登录或 Token 无效 |
| `PERMISSION_DENIED` | 无权限操作该资源 |
| `VALIDATION_ERROR` | 请求字段不合法 |
| `LISTING_NOT_FOUND` | 商品不存在 |
| `LISTING_NOT_ACTIVE` | 商品不可交易 |
| `CANNOT_CHAT_WITH_SELF` | 不能咨询自己的商品 |
| `AI_ANALYSIS_FAILED` | AI 分析失败 |
| `UPLOAD_INVALID_TYPE` | 文件类型不支持 |
| `RATE_LIMITED` | 操作过于频繁 |

错误响应格式：

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "标题长度需要在 5 到 80 字之间",
    "fields": {
      "title": "too_short"
    }
  }
}
```

## 12. MVP 开发优先级

### Phase 1：基础闭环

- Firebase Auth 登录注册。
- 用户资料读写。
- 地址管理。
- 商品图片上传。
- AI 分析接口 mock 或真实接入。
- 商品发布。
- 首页推荐流、搜索、筛选、详情。
- 收藏、点赞、浏览记录。

### Phase 2：聊天闭环

- conversations 集合。
- messages 子集合。
- 联系卖家创建会话。
- 实时消息监听。
- 未读数。
- FCM 推送。
- 聊天图片上传。

### Phase 3：交易闭环

- 下单。
- 支付状态。
- 自提/配送方式。
- 确认收货。
- 评价。
- 信用分和交易评分计算。

### Phase 4：增长与风控

- 更好的搜索服务。
- 推荐排序。
- 内容审核。
- 举报和封禁。
- AI 价格参考库。
- 后台管理系统。

## 13. 后端给前端的最小对接清单

前端下一步真实联调时，后端至少需要提供：

- 当前登录用户资料接口。
- 商品图片上传能力。
- AI 识别估价接口。
- 发布商品接口。
- 商品列表/搜索/详情接口。
- 收藏/点赞接口。
- 创建或获取聊天会话接口。
- Firestore 聊天集合和安全规则。
- FCM Token 上报接口。

## 14. 关键验收标准

- 用户可以注册登录并拿到稳定的 `userId`。
- 用户可以上传 1 到 9 张商品图片。
- AI 接口可以返回类别、品牌、型号、成色、价格区间、标题、描述、标签和置信度。
- 用户可以修改 AI 结果并发布商品。
- 市场首页可以分页加载商品。
- 搜索和筛选可以按关键字、价格、距离、成色、品牌过滤。
- 商品详情会记录浏览数。
- 收藏和点赞不会重复计数。
- 买家点击 “联系卖家” 能打开或创建唯一会话。
- 双方聊天消息可以实时同步。
- 未读数在消息列表正确显示。
- 非会话参与者无法读取聊天内容。
- 商品位置默认展示模糊范围，不能泄露卖家精确地址。
