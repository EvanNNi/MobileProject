import OpenAI from "openai";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {initializeApp} from "firebase-admin/app";
import * as logger from "firebase-functions/logger";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const openaiModel = defineString("OPENAI_LISTING_MODEL", {
  default: "gpt-5-mini",
});

type AnalyzeListingRequest = {
  imagePaths?: unknown;
  currency?: unknown;
  locationLabel?: unknown;
  analysisStage?: unknown;
  userConditionHint?: unknown;
  userEditedFields?: unknown;
  authToken?: unknown;
};

type TranslateListingTextRequest = {
  listingId?: unknown;
  authToken?: unknown;
};

type AnalysisStage = "recognition" | "pricing";

type UserEditedFields = {
  category?: string;
  brand?: string;
  model?: string;
  condition?: string;
  title?: string;
  description?: string;
  titleEn?: string;
  descriptionEn?: string;
};

type RecognizedListingItem = {
  category: string;
  brand: string;
  model: string;
  condition: string;
  confidence: number;
  title: string;
  description: string;
  titleEn: string;
  descriptionEn: string;
  tags: string[];
  tagsEn: string[];
  reasoningBrief: string;
  warnings: string[];
};

type ListingAnalysisResult = {
  category: string;
  brand: string;
  model: string;
  condition: string;
  estimatedLow: number;
  estimatedHigh: number;
  suggestedPrice: number;
  originalPrice: number;
  originalPriceNote: string;
  confidence: number;
  title: string;
  description: string;
  titleEn: string;
  descriptionEn: string;
  tags: string[];
  tagsEn: string[];
  reasoningBrief: string;
  warnings: string[];
  recognizedItems: RecognizedListingItem[];
};

type ListingTranslationResult = {
  titleEn: string;
  descriptionEn: string;
  tagsEn: string[];
};

type ImageInput = {
  path: string;
  dataUrl: string;
};

const maxImages = 4;
const maxImageBytes = 8 * 1024 * 1024;

export const analyzeListing = onCall(
  {
    region: "europe-west2",
    timeoutSeconds: 120,
    memory: "1GiB",
    secrets: [openaiApiKey],
    invoker: "public",
  },
  async (request) => {
    const data = (request.data ?? {}) as AnalyzeListingRequest;
    const ownerId = await resolveAuthUid(request.auth?.uid, data.authToken);
    const imagePaths = parseImagePaths(data.imagePaths);
    assertOwnedImagePaths(imagePaths, ownerId);
    const currency = parseOptionalString(data.currency, "GBP");
    const locationLabel = parseOptionalString(data.locationLabel, "London");
    const analysisStage = parseAnalysisStage(data.analysisStage);
    const userConditionHint = parseOptionalString(
      data.userConditionHint,
      "用户未提供成色补充"
    );
    const userEditedFields = parseUserEditedFields(data.userEditedFields);

    const images = await loadImagesFromStorage(imagePaths);
    const result = await analyzeWithOpenAI({
      images,
      currency,
      locationLabel,
      analysisStage,
      userConditionHint,
      userEditedFields,
    });

    const analysisRef = await getFirestore().collection("listingAnalyses").add({
      ownerId,
      imagePaths,
      currency,
      locationLabel,
      analysisStage,
      userConditionHint,
      userEditedFields,
      model: openaiModel.value(),
      result,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("Listing analysis completed", {
      analysisId: analysisRef.id,
      uid: ownerId,
      usedExplicitTokenFallback: !request.auth?.uid,
      imageCount: imagePaths.length,
      analysisStage,
      category: result.category,
      suggestedPrice: result.suggestedPrice,
      recognizedItemCount: result.recognizedItems.length,
    });

    return {
      analysisId: analysisRef.id,
      ...result,
    };
  }
);

export const translateListingText = onCall(
  {
    region: "europe-west2",
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: [openaiApiKey],
    invoker: "public",
  },
  async (request) => {
    const data = (request.data ?? {}) as TranslateListingTextRequest;
    await resolveAuthUid(request.auth?.uid, data.authToken);
    const listingId = parseOptionalString(data.listingId, "");
    if (!listingId) {
      throw new HttpsError("invalid-argument", "listingId 不能为空。");
    }

    const listingRef = getFirestore().collection("listings").doc(listingId);
    const snapshot = await listingRef.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "没有找到这个商品。");
    }

    const listing = snapshot.data() ?? {};
    const existing = {
      titleEn: optionalTrimmedString(listing.titleEn),
      descriptionEn: optionalTrimmedString(listing.descriptionEn),
      tagsEn: toStringArray(listing.tagsEn),
    };
    if (existing.titleEn && existing.descriptionEn) {
      return {
        titleEn: existing.titleEn,
        descriptionEn: existing.descriptionEn,
        tagsEn: existing.tagsEn,
      };
    }

    const translated = await translateListingWithOpenAI({
      title: toStringValue(listing.title, ""),
      description: toStringValue(listing.description, ""),
      tags: toStringArray(listing.tags),
      category: toStringValue(listing.category, ""),
      condition: toStringValue(listing.condition, ""),
      brand: toStringValue(listing.brand, ""),
      model: toStringValue(listing.model, ""),
    });

    await listingRef.set(
      {
        titleEn: translated.titleEn,
        descriptionEn: translated.descriptionEn,
        tagsEn: translated.tagsEn,
        translatedAt: FieldValue.serverTimestamp(),
        translationModel: openaiModel.value(),
      },
      {merge: true}
    );

    logger.info("Listing text translated", {
      listingId,
      titleEn: translated.titleEn,
    });

    return translated;
  }
);

async function resolveAuthUid(
  callableUid: string | undefined,
  explicitAuthToken: unknown
): Promise<string> {
  if (callableUid) {
    return callableUid;
  }

  if (typeof explicitAuthToken !== "string" || explicitAuthToken.length === 0) {
    throw new HttpsError("unauthenticated", "请先登录，再使用 AI 识别。");
  }

  try {
    const decodedToken = await getAuth().verifyIdToken(explicitAuthToken);
    return decodedToken.uid;
  } catch (error) {
    logger.warn("Failed to verify explicit Firebase auth token", {error});
    throw new HttpsError(
      "unauthenticated",
      "登录状态已失效，请重新登录后再试。"
    );
  }
}

async function loadImagesFromStorage(imagePaths: string[]): Promise<ImageInput[]> {
  const bucket = getStorage().bucket();

  return Promise.all(
    imagePaths.map(async (path) => {
      const file = bucket.file(path);
      const [exists] = await file.exists();
      if (!exists) {
        throw new HttpsError("not-found", `图片不存在：${path}`);
      }

      const [metadata] = await file.getMetadata();
      const contentType = metadata.contentType ?? inferContentType(path);
      if (!contentType.startsWith("image/")) {
        throw new HttpsError("invalid-argument", `文件不是图片：${path}`);
      }

      const [buffer] = await file.download();
      if (buffer.byteLength > maxImageBytes) {
        throw new HttpsError(
          "invalid-argument",
          `单张图片不能超过 ${maxImageBytes / 1024 / 1024}MB：${path}`
        );
      }

      return {
        path,
        dataUrl: `data:${contentType};base64,${buffer.toString("base64")}`,
      };
    })
  );
}

async function analyzeWithOpenAI(params: {
  images: ImageInput[];
  currency: string;
  locationLabel: string;
  analysisStage: AnalysisStage;
  userConditionHint: string;
  userEditedFields: UserEditedFields;
}): Promise<ListingAnalysisResult> {
  const client = new OpenAI({apiKey: openaiApiKey.value()});
  const enableWebSearch = params.analysisStage === "pricing";

  const response = await client.responses.create({
    model: openaiModel.value(),
    ...(enableWebSearch
      ? {
          tools: [
            {
              type: "web_search" as const,
              search_context_size: "medium" as const,
              user_location: {
                type: "approximate" as const,
                city: "London",
                country: "GB",
                timezone: "Europe/London",
              },
            },
          ],
          include: ["web_search_call.action.sources" as const],
        }
      : {}),
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text:
              "你是二手交易平台的商品识别与估价助手。你需要根据图片识别商品，" +
              "查找物品的真实价格，输出适合英国二手市场的发布信息。" +
              "估价不是鉴定或承诺成交价，应偏高、可解释，并在不确定时降低 confidence。",
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: buildAnalysisPrompt(params),
          },
          ...params.images.map((image) => ({
            type: "input_image" as const,
            image_url: image.dataUrl,
            detail: "auto" as const,
          })),
        ],
      },
    ],
    text: {
      format: {
        type: "json_schema",
        name: "listing_analysis",
        strict: true,
        schema: listingAnalysisSchema,
      },
    },
  });

  const outputText = response.output_text;
  if (!outputText) {
    throw new HttpsError("internal", "AI 没有返回可解析的结果。");
  }

  return normalizeAnalysisResult(JSON.parse(outputText));
}

async function translateListingWithOpenAI(params: {
  title: string;
  description: string;
  tags: string[];
  category: string;
  condition: string;
  brand: string;
  model: string;
}): Promise<ListingTranslationResult> {
  const client = new OpenAI({apiKey: openaiApiKey.value()});
  const response = await client.responses.create({
    model: openaiModel.value(),
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text:
              "You translate second-hand marketplace listing text into natural UK English. " +
              "Keep brand names and model names unchanged. Do not add details that are not present.",
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: [
              "Translate this listing for an English UI.",
              `Title: ${params.title}`,
              `Description: ${params.description}`,
              `Category: ${params.category}`,
              `Condition: ${params.condition}`,
              `Brand: ${params.brand}`,
              `Model: ${params.model}`,
              `Tags: ${params.tags.join(", ")}`,
              "Return concise, seller-like English. titleEn should be searchable and natural. descriptionEn should be 1-2 short sentences.",
            ].join("\n"),
          },
        ],
      },
    ],
    text: {
      format: {
        type: "json_schema",
        name: "listing_translation",
        strict: true,
        schema: listingTranslationSchema,
      },
    },
  });

  const outputText = response.output_text;
  if (!outputText) {
    throw new HttpsError("internal", "AI 没有返回翻译结果。");
  }

  return normalizeListingTranslation(JSON.parse(outputText), params);
}

function buildAnalysisPrompt(params: {
  currency: string;
  locationLabel: string;
  analysisStage: AnalysisStage;
  userConditionHint: string;
  userEditedFields: UserEditedFields;
}): string {
  const lines = [
    "请分析这些商品图片，并生成二手商品发布草稿。",
    `当前阶段：${params.analysisStage === "recognition" ? "图片识别" : "AI 估价"}`,
    `货币：${params.currency}`,
    `市场位置：${params.locationLabel}（用户选择的位置，若为空后端目前默认 London）`,
    "要求：",
    "- category 使用中文，例如 数码、球鞋、箱包、相机、家具、其他。",
    "- brand/model 无法判断时填写“未知”，不要编造。",
    "- condition 必须是：全新、几乎全新、轻微使用、明显使用、无法判断。",
    "- title 要适合二手平台搜索，简洁包含品牌/型号/品类。",
    "- description 要像普通卖家自己写的，不要像检测报告或 AI 总结；口语自然、极简，1 到 2 句，最多 80 个中文字符。",
    "- description 只写买家关心的信息，例如成色、功能、配件、是否可面交；不要写估价依据、搜索来源、链接或冗长免责声明。",
    "- titleEn 必须是 title 的自然英文版本，适合英国二手平台搜索，不要夹杂中文。",
    "- descriptionEn 必须是 description 的自然英文版本，像英国卖家自己写的 1 到 2 句简短文案，不要夹杂中文。",
    "- tags 返回 3 到 8 个中文标签。",
    "- tagsEn 返回与 tags 对应的英文标签，数量和顺序尽量一致，不要夹杂中文。",
    "- warnings 写出不确定因素，例如图片角度不足、无法判断真伪、需要人工确认型号。",
    "- 如果图片中出现多个独立可售物品，请分别识别为 recognizedItems 候选；每个候选都要有 category、brand、model、condition、confidence、title、description、titleEn、descriptionEn、tags、tagsEn、reasoningBrief、warnings。",
    "- 多物品判断要主动：不同品类、不同品牌/型号、不同颜色/尺码、配件中有单独转售价值的物品，都应拆成候选；不要只识别画面中最大的主体。",
    "- 如果用户上传多张图片，先判断它们是同一商品的不同角度，还是多个不同商品；如果是多个不同商品，recognizedItems 必须逐个列出。",
    "- 如果不确定两个物品是不是同一商品，请保守拆成两个候选，并在 warnings 中提示需要用户确认。",
    "- 顶层字段仍返回最适合作为默认发布的那个物品，通常是图片主体或最清晰的物品。",
  ];

  if (params.analysisStage === "recognition") {
    lines.push(
      "本阶段只做图片识别和发布草稿生成，不做价格判断。",
      "estimatedLow、estimatedHigh、suggestedPrice 全部返回 0。",
      "originalPrice 返回 0，originalPriceNote 返回空字符串。",
      "recognizedItems 返回 1 到 5 个可单独发布的物品候选；如果画面里有多个独立物品，必须返回多个候选；如果只识别到一个物品，也返回包含该物品的数组。",
      "reasoningBrief 简短说明识别依据，而不是估价依据。"
    );
  } else {
    lines.push(
      `用户成色补充：${params.userConditionHint}`,
      "用户已经确认或修正了以下识别信息，估价时应优先参考；如果图片明显冲突，请在 warnings 中指出。",
      ...formatUserEditedFields(params.userEditedFields),
      "本阶段必须使用 web_search 搜索同型号或近似型号的英国全新售价以及二手市场价格，再给出估价。",
      "优先搜索 eBay UK sold/completed、Gumtree、Facebook Marketplace、CeX、Back Market、Vinted/Depop 等同款或近似二手成交/在售价格；如果没有同款，搜索相近型号并在 warnings 中说明。",
      "对于建议价可能高于 50 GBP 的商品，或相机、笔记本、手机、奢侈品、设计师包、专业设备等高价值商品，还要尝试搜索官方原价、首发 MSRP 或当前新品价格，用于校准折旧比例。",
      "估价不要直接取最低或最高搜索结果；应剔除明显异常价格、配件缺失、损坏件、翻新商家溢价，再结合图片成色和用户补充给出保守区间。",
      "- estimatedLow、estimatedHigh、suggestedPrice 使用整数，不要带货币符号。",
      "- suggestedPrice 应落在 estimatedLow 和 estimatedHigh 之间。",
      "- originalPrice 使用整数，表示搜索到的英国全新售价、官方原价、首发 MSRP 或当前新品价格；无法确认时返回 0。",
      "- originalPriceNote 用一句适合前端小字展示的话说明原价来源或无法确认原因，不要超过 40 个中文字符。",
      "- reasoningBrief 简短说明估价依据，应同时参考图片、用户修正信息、搜索到的二手价格和必要时的原价信息。",
      "- warnings 中写出搜索依据不足、型号不确定、原价未找到或搜索结果波动大的情况。",
      "- recognizedItems 本阶段返回空数组。"
    );
  }

  return lines.join("\n");
}

function normalizeAnalysisResult(raw: unknown): ListingAnalysisResult {
  if (!isRecord(raw)) {
    throw new HttpsError("internal", "AI 返回格式错误。");
  }

  const estimatedLow = toNonNegativeInteger(raw.estimatedLow);
  const estimatedHigh = Math.max(toNonNegativeInteger(raw.estimatedHigh), estimatedLow);
  const suggestedPrice = clamp(
    toNonNegativeInteger(raw.suggestedPrice),
    estimatedLow,
    estimatedHigh
  );

  return {
    category: toStringValue(raw.category, "其他"),
    brand: toStringValue(raw.brand, "未知"),
    model: toStringValue(raw.model, "未知"),
    condition: toStringValue(raw.condition, "无法判断"),
    estimatedLow,
    estimatedHigh,
    suggestedPrice,
    originalPrice: toNonNegativeInteger(raw.originalPrice),
    originalPriceNote: toStringValue(raw.originalPriceNote, ""),
    confidence: clamp(toNumberValue(raw.confidence, 0.5), 0, 1),
    title: toStringValue(raw.title, "二手闲置商品"),
    description: toStringValue(raw.description, "图片识别生成的商品描述，请发布前检查。"),
    titleEn: toStringValue(raw.titleEn, "Second-hand item"),
    descriptionEn: toStringValue(
      raw.descriptionEn,
      "AI-generated listing description. Please check before publishing."
    ),
    tags: toStringArray(raw.tags).slice(0, 8),
    tagsEn: toStringArray(raw.tagsEn).slice(0, 8),
    reasoningBrief: toStringValue(raw.reasoningBrief, "基于图片和二手市场常识估价。"),
    warnings: toStringArray(raw.warnings).slice(0, 6),
    recognizedItems: normalizeRecognizedItems(raw.recognizedItems).slice(0, 5),
  };
}

function normalizeListingTranslation(
  raw: unknown,
  fallback: {title: string; description: string; tags: string[]}
): ListingTranslationResult {
  if (!isRecord(raw)) {
    throw new HttpsError("internal", "AI 返回翻译格式错误。");
  }

  const titleEn = toStringValue(raw.titleEn, fallback.title || "Second-hand item");
  const descriptionEn = toStringValue(raw.descriptionEn, fallback.description);
  const tagsEn = toStringArray(raw.tagsEn).slice(0, 8);

  return {
    titleEn,
    descriptionEn,
    tagsEn: tagsEn.length > 0 ? tagsEn : fallback.tags,
  };
}

function normalizeRecognizedItems(raw: unknown): RecognizedListingItem[] {
  if (!Array.isArray(raw)) {
    return [];
  }

  return raw
    .filter(isRecord)
    .map((item) => ({
      category: toStringValue(item.category, "其他"),
      brand: toStringValue(item.brand, "未知"),
      model: toStringValue(item.model, "未知"),
      condition: toStringValue(item.condition, "无法判断"),
      confidence: clamp(toNumberValue(item.confidence, 0.5), 0, 1),
      title: toStringValue(item.title, "二手闲置商品"),
      description: toStringValue(item.description, ""),
      titleEn: toStringValue(item.titleEn, "Second-hand item"),
      descriptionEn: toStringValue(item.descriptionEn, ""),
      tags: toStringArray(item.tags).slice(0, 8),
      tagsEn: toStringArray(item.tagsEn).slice(0, 8),
      reasoningBrief: toStringValue(item.reasoningBrief, "基于图片识别。"),
      warnings: toStringArray(item.warnings).slice(0, 6),
    }));
}

function parseImagePaths(value: unknown): string[] {
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "imagePaths 必须是数组。");
  }

  const paths = value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter(Boolean);

  if (paths.length === 0) {
    throw new HttpsError("invalid-argument", "至少需要上传一张图片。");
  }
  if (paths.length > maxImages) {
    throw new HttpsError("invalid-argument", `最多支持 ${maxImages} 张图片。`);
  }

  for (const path of paths) {
    if (!path.startsWith("listing_images/")) {
      throw new HttpsError(
        "permission-denied",
        "AI 识别只允许读取 listing_images 下的商品图片。"
      );
    }
  }

  return paths;
}

function parseAnalysisStage(value: unknown): AnalysisStage {
  return value === "recognition" ? "recognition" : "pricing";
}

function parseUserEditedFields(value: unknown): UserEditedFields {
  if (!isRecord(value)) {
    return {};
  }

  return {
    category: optionalTrimmedString(value.category),
    brand: optionalTrimmedString(value.brand),
    model: optionalTrimmedString(value.model),
    condition: optionalTrimmedString(value.condition),
    title: optionalTrimmedString(value.title),
    description: optionalTrimmedString(value.description),
    titleEn: optionalTrimmedString(value.titleEn),
    descriptionEn: optionalTrimmedString(value.descriptionEn),
  };
}

function formatUserEditedFields(fields: UserEditedFields): string[] {
  const rows = [
    ["分类", fields.category],
    ["品牌", fields.brand],
    ["型号", fields.model],
    ["成色", fields.condition],
    ["标题", fields.title],
    ["描述", fields.description],
    ["英文标题", fields.titleEn],
    ["英文描述", fields.descriptionEn],
  ];

  const formatted = rows
    .filter((row): row is [string, string] => typeof row[1] === "string" && row[1].length > 0)
    .map(([label, value]) => `- 用户${label}：${value}`);

  return formatted.length > 0 ? formatted : ["- 用户没有提供额外修正字段。"];
}

function assertOwnedImagePaths(imagePaths: string[], ownerId: string): void {
  const ownerPrefix = `listing_images/${ownerId}/`;
  for (const path of imagePaths) {
    if (!path.startsWith(ownerPrefix)) {
      throw new HttpsError(
        "permission-denied",
        "AI 识别只能读取当前账号上传的商品图片。"
      );
    }
  }
}

function parseOptionalString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function optionalTrimmedString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function inferContentType(path: string): string {
  const lower = path.toLowerCase();
  if (lower.endsWith(".png")) {
    return "image/png";
  }
  if (lower.endsWith(".webp")) {
    return "image/webp";
  }
  return "image/jpeg";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toStringValue(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter(Boolean);
}

function toNumberValue(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function toNonNegativeInteger(value: unknown): number {
  return Math.max(0, Math.round(toNumberValue(value, 0)));
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

const listingTranslationSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    titleEn: {
      type: "string",
      description: "Natural UK English listing title.",
    },
    descriptionEn: {
      type: "string",
      description: "Natural UK English listing description, 1-2 short sentences.",
    },
    tagsEn: {
      type: "array",
      minItems: 0,
      maxItems: 8,
      items: {
        type: "string",
      },
    },
  },
  required: ["titleEn", "descriptionEn", "tagsEn"],
} as const;

const listingAnalysisSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    category: {
      type: "string",
      description: "商品类别，中文。",
    },
    brand: {
      type: "string",
      description: "品牌，无法判断时填写“未知”。",
    },
    model: {
      type: "string",
      description: "型号，无法判断时填写“未知”。",
    },
    condition: {
      type: "string",
      enum: ["全新", "几乎全新", "轻微使用", "明显使用", "无法判断"],
    },
    estimatedLow: {
      type: "integer",
      minimum: 0,
      description: "建议价格区间下限，整数。",
    },
    estimatedHigh: {
      type: "integer",
      minimum: 0,
      description: "建议价格区间上限，整数。",
    },
    suggestedPrice: {
      type: "integer",
      minimum: 0,
      description: "推荐发布价，整数。",
    },
    originalPrice: {
      type: "integer",
      minimum: 0,
      description: "搜索到的英国全新售价、官方原价、首发 MSRP 或当前新品价格；无法确认时返回 0。",
    },
    originalPriceNote: {
      type: "string",
      description: "原价来源或无法确认原因，适合前端小字展示。",
    },
    confidence: {
      type: "number",
      minimum: 0,
      maximum: 1,
      description: "识别与估价信心分。",
    },
    title: {
      type: "string",
      description: "推荐商品标题。",
    },
    description: {
      type: "string",
      description: "推荐商品描述。",
    },
    titleEn: {
      type: "string",
      description: "推荐商品标题的自然英文版本。",
    },
    descriptionEn: {
      type: "string",
      description: "推荐商品描述的自然英文版本。",
    },
    tags: {
      type: "array",
      minItems: 3,
      maxItems: 8,
      items: {
        type: "string",
      },
    },
    tagsEn: {
      type: "array",
      minItems: 3,
      maxItems: 8,
      items: {
        type: "string",
      },
    },
    reasoningBrief: {
      type: "string",
      description: "简短说明估价依据，不要暴露系统提示。",
    },
    warnings: {
      type: "array",
      maxItems: 6,
      items: {
        type: "string",
      },
    },
    recognizedItems: {
      type: "array",
      maxItems: 5,
      description: "图片识别阶段返回的多个可单独发布物品候选。",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          category: {
            type: "string",
            description: "商品类别，中文。",
          },
          brand: {
            type: "string",
            description: "品牌，无法判断时填写“未知”。",
          },
          model: {
            type: "string",
            description: "型号，无法判断时填写“未知”。",
          },
          condition: {
            type: "string",
            enum: ["全新", "几乎全新", "轻微使用", "明显使用", "无法判断"],
          },
          confidence: {
            type: "number",
            minimum: 0,
            maximum: 1,
          },
          title: {
            type: "string",
          },
          description: {
            type: "string",
          },
          titleEn: {
            type: "string",
          },
          descriptionEn: {
            type: "string",
          },
          tags: {
            type: "array",
            maxItems: 8,
            items: {
              type: "string",
            },
          },
          tagsEn: {
            type: "array",
            maxItems: 8,
            items: {
              type: "string",
            },
          },
          reasoningBrief: {
            type: "string",
          },
          warnings: {
            type: "array",
            maxItems: 6,
            items: {
              type: "string",
            },
          },
        },
        required: [
          "category",
          "brand",
          "model",
          "condition",
          "confidence",
          "title",
          "description",
          "titleEn",
          "descriptionEn",
          "tags",
          "tagsEn",
          "reasoningBrief",
          "warnings",
        ],
      },
    },
  },
  required: [
    "category",
    "brand",
    "model",
    "condition",
    "estimatedLow",
    "estimatedHigh",
    "suggestedPrice",
    "originalPrice",
    "originalPriceNote",
    "confidence",
    "title",
    "description",
    "titleEn",
    "descriptionEn",
    "tags",
    "tagsEn",
    "reasoningBrief",
    "warnings",
    "recognizedItems",
  ],
} as const;
