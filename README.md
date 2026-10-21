# 禾智诊 · 农作物缺素症识别与科学施肥建议智能体

> OHCP 一小时智能编程大赛参赛项目｜Java 17 + Spring Boot 3.4 + Spring AI + LangChain4j + 本地 RAG
>
> 一句话：**先查本地知识库，再让大模型整理**。没有 API Key、没有网络也能完整演示；模型不能绕过知识库直接给答案。

---

## 1. 项目简介

农户看到叶片发黄、发紫、叶缘焦枯时，很难判断缺哪种元素，容易盲目施肥，增加成本并造成土壤板结与面源污染。本项目接收「作物类型 + 症状部位 + 症状表现 + 发生环境」，先从爬虫构建的本地私有缺素知识库检索，输出多候选缺素与匹配置信度，再生成包含六个模块的科学施肥建议，并在结果中自然嵌入 1—2 行【农技小感悟】。

核心业务闭环：

```text
前端输入症状
   ↓  POST /api/diagnose
后端参数校验
   ↓
本地知识库混合检索（作物过滤 + 症状关键词 + 本地向量余弦）  ← 强制第一步
   ↓
证据不足 → 拒答，不调用大模型，不给施肥剂量
证据充分 → 取 Top-K 证据，组织六模块建议
   ↓
可选：Spring AI 仅对已有证据做 ≤120 字摘要（失败自动回退）
   ↓
返回候选、建议、风险等级、知识来源、农技小感悟 → 前端展示
```

### 评分标准对照

| 评分项 | 分值 | 本项目落点 |
|---|---|---|
| 业务功能实现 | 35 | 症状输入、多候选识别与置信度、六模块施肥建议、风险提示、完整前端回显 |
| 技术规范落地 | 30 | 前后端分离 API；Spring Boot + Spring AI + LangChain4j；Jsoup 爬虫；JSON 本地知识库；清洗/切片/向量化；强制 RAG |
| 课程思政 | 20 | 随业务结果输出浅黄色【农技小感悟】，绿色施肥优先，粮食安全与科技助农 |
| 创新设计 | 10 | 规则 + 本地向量的**风险分级**与**农户/农技人员双模式**，现场可切换演示 |
| 文档交付 | 5 | 源码、README、PPT 大纲、测试用例、真实 API 返回样例 |

---

## 2. 环境与启动

### 2.1 环境要求

| 组件 | 版本 | 说明 |
|---|---|---|
| JDK | 17+（已在 21 验证） | `java -version` |
| Maven | 3.9+ | `mvn -version`；仅源码构建需要 |
| 浏览器 | Chrome / Edge | 现场演示 |
| 网络 | 非必需 | 默认离线运行；仅首次构建需下载依赖 |

不需要数据库、Node.js、Python、API Key。

### 2.2 零依赖快速演示（推荐现场使用）

本地交付包附带已验证的 `dist/crop-nutrition-agent-1.0.0.jar`，不需要安装 Maven：

```bat
cd crop-nutrition-agent
demo.bat
```

或手动：

```bash
java -jar dist/crop-nutrition-agent-1.0.0.jar
```

打开 <http://localhost:8080/> 即可。修改源码后请按 2.4 重新打包，避免运行旧包。

### 2.3 源码一键启动

Windows：

```bat
cd crop-nutrition-agent
start.bat
```

macOS / Linux：

```bash
cd crop-nutrition-agent
chmod +x start.sh && ./start.sh
```

或直接使用 Maven：

```bash
mvn spring-boot:run
```

启动后打开 <http://localhost:8080/>，健康检查 <http://localhost:8080/api/health> 应返回：

```json
{"status":"UP","knowledgeItems":6,"ragRequired":true}
```

### 2.4 打包运行

```bash
mvn clean package
java -jar target/crop-nutrition-agent-1.0.0.jar
```

### 2.5 可选：启用 Spring AI 证据摘要

默认 `LLM_ENABLED=false`，全程本地。需要展示“RAG + 大模型整理”时：

```powershell
$env:LLM_ENABLED="true"
$env:OPENAI_API_KEY="你的Key"
$env:OPENAI_BASE_URL="https://api.openai.com"   # 兼容 OpenAI Chat Completions 的服务
$env:OPENAI_MODEL="gpt-4o-mini"
mvn spring-boot:run
```

开启后响应中的 `generationMode` 为 `LOCAL_RAG_THEN_SPRING_AI`；网络或 Key 异常会自动降级为 `LOCAL_RAG_FALLBACK`，业务不中断。模型只收到 Top-K 证据和用户症状，提示词禁止新增剂量与事实。**施肥模块、剂量、安全项始终来自本地 JSON。**

### 2.6 在 VS Code 中运行（推荐开发调试）

**第一步：安装扩展与 JDK**

1. 安装 [Extension Pack for Java](https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-pack)（含 Java 语言支持、Maven、调试器）。
2. 可选安装 Spring Boot Extension Pack，获得 `application.yml` 提示和 Spring Boot Dashboard。
3. 安装 JDK 17+。VS Code 中 `Ctrl+Shift+P` → `Java: Configure Java Runtime`，选择已安装的 JDK 17/21。
4. 用 VS Code 打开 **`crop-nutrition-agent` 目录**（必须是包含 `pom.xml` 的根目录），等待右下角 Java 项目导入完成。

**第二步：选择一种启动方式**

方式 A：最快演示，不需要 Maven

- 打开终端（`` Ctrl+` ``），执行：

```bat
.\demo.bat
```

- 或菜单 `终端 → 运行任务` → 选择“运行预构建演示包（无需 Maven）”。
- 浏览器打开 <http://localhost:8080/>。

方式 B：源码运行 / 断点调试

- 打开 `src/main/java/com/ohcp/cropagent/CropNutritionApplication.java`，点击 `main` 方法上方的 **Run**。
- 或直接按 `F5`，使用项目内置的 `.vscode/launch.json`（配置名“禾智诊：启动后端”）。
- 或在终端执行：

```bat
.\mvnw.cmd spring-boot:run
```

macOS / Linux 使用 `./mvnw spring-boot:run`（首次可 `chmod +x mvnw`）。

> `mvnw` 首次运行会下载 Maven 3.9.11。若公司网络/代理导致下载失败，安装 Maven 3.9+ 后改用 `mvn spring-boot:run`，或直接用方式 A 的预构建包。VS Code 若提示无法解析依赖，通常是 Maven 未安装或 `mvnw` 下载被拦截；先确认 `java -version` 与 Maven 均可用，再执行 `Java: Clean Java Language Server Workspace`。
>
> 如果通过 GitHub 网页上传，33.5 MB 的 jar 超过网页 25 MB 单文件限制，请按第 14 节把它上传到 **Releases**；源码可用 `mvn spring-boot:run` 启动。用 Git 命令行/GitHub Desktop 推送时则可以直接包含该 jar。

**调试建议**

- 在 `DeficiencyAgent.diagnose()` 与 `KnowledgeBaseService.search()` 打断点，可观察“先检索、后生成”的完整链路。
- 修改 `application.yml` 的 `server.port` 可换端口；前端用 `window.API_BASE` 指向新地址。
- 终端中文乱码时执行 `chcp 65001`；项目源码与页面均为 UTF-8。

### 2.7 单独部署前端（前后端分离）

前端源码独立在 `frontend/index.html`，构建时由 Maven 复制到 `classpath:/static/` 以便一键演示。也可以：

- 直接用浏览器打开 `frontend/index.html`（`file://`，页面自动请求 `http://localhost:8080`）；
- 或部署到 Nginx / 静态托管，在页面加载前设置 `window.API_BASE = "http://your-backend:8080"`。

页面只通过 `/api/diagnose` 与后端通信，可替换为 Vue / 小程序而不改后端。

---

## 3. 目录结构

```text
crop-nutrition-agent/
├── pom.xml                          # Spring Boot 3.4.13 + Spring AI 1.0.0 + LangChain4j 1.0.0
├── mvnw / mvnw.cmd / .mvn/          # Maven Wrapper，VS Code 可直接构建
├── .vscode/                         # 一键运行任务、F5 调试配置、扩展推荐
├── .github/workflows/build.yml      # GitHub Actions：自动 mvn test
├── .gitattributes                   # 固定 .bat 为 CRLF、mvnw 为 LF
├── start.bat / start.sh             # 源码一键启动脚本
├── demo.bat                         # 预构建包一键演示（无需 Maven）
├── dist/                            # 预构建可运行 jar（可选）
├── README.md
├── frontend/
│   └── index.html                   # 原生 HTML+CSS+JS，单文件前端
├── docs/
│   ├── PPT大纲.md                    # 13 页比赛汇报大纲（含创新点讲法）
│   ├── 测试用例与预期结果.md          # 6 个演示/验收用例
│   ├── 示例返回.json                 # 真实调用 API 保存的完整返回
│   ├── 爬虫输出样例.json              # 清洗切片 + 64 维向量的结构化输出
│   └── GitHub发布指南.md              # 三种上传方式与链接说明
└── src/
    ├── main/
    │   ├── java/com/ohcp/cropagent/
    │   │   ├── CropNutritionApplication.java
    │   │   ├── controller/DiagnosisController.java
    │   │   ├── crawler/AgricultureKnowledgeCrawler.java
    │   │   ├── model/
    │   │   │   ├── DiagnosisRequest.java
    │   │   │   ├── DiagnosisResponse.java
    │   │   │   ├── KnowledgeItem.java
    │   │   │   └── RetrievalHit.java
    │   │   └── service/
    │   │       ├── DeficiencyAgent.java        # LangChain4j 提示模板 + 智能体编排
    │   │       ├── KnowledgeBaseService.java   # 加载、混合检索、置信度证据
    │   │       └── LocalVectorizer.java        # 64 维本地哈希向量 + 余弦
    │   └── resources/
    │       ├── application.yml
    │       └── knowledge/deficiency-knowledge.json
    └── test/java/com/ohcp/cropagent/service/
        ├── DeficiencyAgentTest.java            # 主链路、风险分级、拒答边界
        └── LocalVectorizerTest.java
```

---

## 4. 技术架构与关键设计

### 4.1 为什么不是“裸大模型”

1. **入口强制检索**：`DeficiencyAgent.diagnose()` 第一行调用 `KnowledgeBaseService.search()`，在这之前没有任何模型请求。
2. **无证据即拒答**：作物不在知识库、或同作物内没有症状关键词且语义相似度低于阈值，返回 `LOCAL_RAG_REJECTED`，不提供剂量。
3. **知识即答案主体**：缺素简介、农艺调控、有机/生物肥、化肥追施、安全提醒全部直接取自命中的 JSON 条目。
4. **模型只做压缩**：可选模型调用只接收 Top-K 证据，要求“不得新增剂量、事实或诊断”，输出 ≤120 字摘要；异常自动回退固定模板。
5. **证据可追溯**：响应携带知识条目 id、来源标题、来源 URL 和检索分数，页面直接展示。

### 4.2 本地 RAG 检索

`KnowledgeBaseService` 启动时读取 `classpath:knowledge/deficiency-knowledge.json`，对每条知识做：

```text
searchableText = 作物 + 元素 + 症状部位 + 症状描述 + 环境 + 关键词 + 清洗切片
vector = LocalVectorizer.embed(searchableText)   // 64 维特征哈希
```

查询评分（可解释、可复现）：

```text
作物一致                 +0.28（不一致直接排除）
症状/部位/环境/关键词命中  +0.06 ~ +0.10/项，累计上限 0.52
本地向量余弦相似度         ×0.20
总分                      ≤ 1.00
```

排序规则：`score DESC, knowledgeId ASC`，同输入同输出。作物过滤避免“水稻症状匹配到小麦条目”的低级错误；关键词与向量双通道兼顾精确与召回。

### 4.3 LangChain4j 与 Spring AI 的分工

- **LangChain4j**：`PromptTemplate` 管理证据约束提示词，`DeficiencyAgent` 负责“检索 → 判定 → 组装 → 可选润色”的智能体编排，对应 Java 智能体框架要求。
- **Spring AI**：`ChatClient` 作为可选模型适配器，仅做证据摘要；通过 `ObjectProvider` 注入，未配置/调用失败时不影响启动与主链路。
- 两者不互相传递框架类型，业务层只依赖本项目 record，便于替换模型或禁用模型。

### 4.4 风险分级（创新点的一部分）

识别后对用户描述做高风险词扫描：`焦枯 / 坏死 / 全株 / 大面积 / 倒伏`。

- 命中：`risk.level = 高`，提示尽快取样检测、联系农技人员、先小区试施；
- 未命中：`risk.level = 中`，提示 3—7 天观察新叶与长势。

同时根据 `audience` 输出两套表达：

| 模式 | 适用对象 | 农技小感悟表达 |
|---|---|---|
| `farmer` | 农户简易版 | 科学施肥、藏粮于地；青年用 AI 服务三农 |
| `expert` | 农技人员专业版 | 测土配方、数据决策、化肥减量增效、科技助农 |

---

## 5. 爬虫与知识库构建

### 5.1 采集流程

`AgricultureKnowledgeCrawler`（Jsoup）：

```text
公开农技网页
  → 限速抓取（UA 标识、1 秒间隔、10 秒超时）
  → 正文抽取（article/main/.content/.TRS_Editor 中取最长文本）
  → 清洗（去脚本/导航/版权/责任编辑等噪音，压缩空白）
  → 切片（约 420 字，60 字重叠，优先按句号/分号截断）
  → 结构化（作物、元素、来源、日期、切片文本）
  → 本地向量化（64 维）
  → target/crawler/raw-knowledge.json
```

在 IDE 中直接运行 `AgricultureKnowledgeCrawler.main`，或：

```bash
mvn -q -DskipTests package
# 建议在 IDE 中运行（Spring Boot fat jar 不适合直接用 -cp 方式加载依赖）
```

### 5.2 数据治理（必须说明）

- 仅采集公开科普内容，遵守目标网站 `robots.txt`、版权与服务条款，不抓取登录后或付费内容；
- 机器抽取结果**不是可直接使用的施肥处方**，需农技人员标注作物/元素/剂量/适用条件后，人工合并进 `deficiency-knowledge.json`；
- 演示不依赖现场联网：已附 6 条人工审核结构的种子知识（水稻氮/磷/钾、小麦钾、玉米锌、番茄镁）。

### 5.3 知识库 JSON 字段

```json
{
  "id": "rice-n-001",
  "crop": "水稻",
  "element": "N",
  "elementName": "缺氮",
  "baseConfidence": 0.96,
  "symptomParts": ["下部老叶", "老叶", "全株"],
  "symptoms": ["从下部老叶开始均匀发黄", "植株矮小", "分蘖减少"],
  "environments": ["土壤贫瘠", "连续降雨淋失"],
  "introduction": "缺素简介……",
  "agronomicMeasures": ["农艺调控……"],
  "organicPlan": ["有机/生物肥方案……"],
  "chemicalPlan": ["化肥追施方案……"],
  "safetyReminders": ["安全与减量提醒……"],
  "keywords": ["均匀黄化", "老叶先黄"],
  "sourceTitle": "公开农技资料整理：水稻缺氮诊断与调控",
  "sourceUrl": "https://www.caas.cn/",
  "crawledAt": "2026-10-21",
  "chunkText": "清洗后的知识切片，用于向量化与证据展示"
}
```

`vector` 不在种子文件中手工维护：服务启动时由 `chunkText` 等字段实时计算，避免改文案后向量失真；爬虫产出的原始切片会带上 `vector` 与 `reviewStatus`（待农技审核），示例见 [爬虫输出样例.json](docs/爬虫输出样例.json)，便于后续接入向量数据库。

> 数据中的施肥量为教学演示范围，落地必须结合当地测土配方、作物生育期、土壤 pH、肥料标签和农技部门意见调整。

---

## 6. API

### `POST /api/diagnose`

请求：

```json
{
  "crop": "水稻",
  "symptomPart": "下部老叶",
  "symptom": "叶片从下部老叶开始均匀发黄，植株矮小，分蘖减少",
  "environment": "连续降雨后，田块有少量漏水",
  "audience": "farmer"
}
```

- `crop`、`symptom` 必填；`audience` 取 `farmer` / `expert`，默认 `farmer`。

响应（节选，完整见 [示例返回.json](docs/示例返回.json)）：

```json
{
  "crop": "水稻",
  "candidates": [
    {"element": "N", "name": "缺氮", "confidence": 0.94,
     "reason": "命中：下部老叶、从下部老叶开始均匀发黄、植株矮小、分蘖减少"},
    {"element": "K", "name": "缺钾", "confidence": 0.66, "reason": "命中：下部老叶、老叶"}
  ],
  "advice": {
    "deficiencyName": "水稻缺氮",
    "introduction": "氮参与叶绿素、蛋白质和核酸形成……",
    "agronomicMeasures": ["先排查渍害、低温和病害……"],
    "organicPlan": ["优先每亩追施充分腐熟有机肥100—200千克……"],
    "chemicalPlan": ["确认缺氮后，每亩追施尿素4—6千克，分1—2次少量施用……"],
    "safetyReminders": ["雨前、烈日中午和大水漫灌时不施肥……"],
    "llmSummary": "本地知识库命中……首选判断为缺氮……"
  },
  "risk": {"level": "中", "message": "当前可进行田间初筛与小区试施……"},
  "agriReflection": "科学施肥、藏粮于地藏粮于技。青年用AI服务三农……",
  "evidence": [{"knowledgeId": "rice-n-001", "sourceTitle": "……", "sourceUrl": "……", "score": 0.97}],
  "generationMode": "LOCAL_RAG_TEMPLATE",
  "disclaimer": "AI结果仅作田间初筛……"
}
```

`generationMode` 取值：

| 值 | 含义 |
|---|---|
| `LOCAL_RAG_TEMPLATE` | 纯本地检索 + 固定模板（默认，离线） |
| `LOCAL_RAG_THEN_SPRING_AI` | 先本地检索，再由 Spring AI 压缩证据 |
| `LOCAL_RAG_FALLBACK` | 检索成功，但模型调用失败，自动回退 |
| `LOCAL_RAG_REJECTED` | 无可靠证据，拒绝生成 |

### `GET /api/health`

返回 `status`、知识条目数量、`ragRequired=true`，用于现场证明知识库已加载。

---

## 7. 演示流程（90 秒）

1. 打开首页，点击“填入水稻缺氮样例” → “开始本地 RAG 诊断”。
2. 指出顶部 `LOCAL_RAG_TEMPLATE` 标识：全程本地，没有调用大模型。
3. 依次讲解候选置信度 → 缺素简介 → 农艺调控 → **有机/生物肥优先** → 化肥减量 → 安全提醒。
4. 展示黄色【农技小感悟】块与知识来源链接。
5. 把环境改为“全株焦枯，部分倒伏”再次诊断 → 风险变为“高”。
6. 切换“农技人员专业版” → 思政表达与建议视角变化（创新点）。
7. 输入“苹果 / 果实 / 黑色凹陷斑点” → 展示“证据不足，拒绝猜测”（非裸大模型）。

完整用例见 [测试用例与预期结果.md](docs/测试用例与预期结果.md)。

---

## 8. 课程思政设计

| 要求 | 实现 |
|---|---|
| 不单独弹窗、不割裂 | 以浅黄色块内嵌在识别结果/施肥建议之后，1—2 行 |
| 农业与粮食安全 | “科学施肥、藏粮于地藏粮于技”“筑牢粮食生产防线” |
| 科学施肥、绿色农业 | 建议顺序为农艺调控 → 有机/生物肥 → 化肥减量；安全提醒包含面源污染 |
| 科技助农、青年担当 | “青年用 AI 服务三农”“把所学技术服务农业农村” |
| 农技人物故事 | 专业版表达“一代代农技人扎根田间，推进测土配方施肥” |
| 分众表达 | 农户版通俗、专业版强调数据决策与减量增效 |

思政文案由后端随业务结果返回（`agriReflection`），不是前端硬编码弹窗，保证“业务输出到哪，价值引导到哪”。

---

## 9. 创新点：风险分级 + 双模式

**类型**：智能体能力创新 + 场景创新（轻量、可现场演示）。

**思路**：缺素识别不仅要“猜得准”，还要“说得稳”。项目在 RAG 排序之外增加两个低成本能力：

1. **风险分级**：对症状描述做高危词规则扫描，命中“焦枯/坏死/全株/大面积/倒伏”即升级为高风险，提示检测与小区试施，避免直接大面积施肥。
2. **双模式输出**：同一份知识证据，按 `audience` 生成农户简易版或农技人员专业版表达，覆盖基层与专业两类用户。

**实现成本**：一个正则函数 + 一个请求字段 + 一个下拉框，约 10 分钟；不引入额外模型或数据库。

**演示效果**：同一水稻样例，补一句“全株焦枯”后风险由“中”变“高”；切换专业版后【农技小感悟】改为测土配方与减量增效表达。

**价值**：把“能识别”提升为“敢建议、会分级、分对象”，降低误施风险，也让课程思政表达更贴合使用者。

---

## 10. 测试

```bash
mvn test
```

覆盖：

- 本地哈希向量维度与自相似度；
- 水稻缺氮主链路（候选、六模块、证据、思政、离线模式）；
- 高风险词触发风险升级；
- 未知作物拒答；
- 已知作物但症状模糊时同样拒答。

> 测试为纯 Java 构造，不启动 Spring 容器、不依赖网络/API Key，适合赛场快速回归。

---

## 11. 一小时开发排期（3 人小组）

| 时间 | 角色 A（后端/RAG） | 角色 B（前端/联调） | 角色 C（数据/文档/PPT） |
|---|---|---|---|
| 0—10 min | 建工程、定 API 契约 | 页面骨架、表单 | 知识条目整理、PPT 封面/痛点 |
| 10—30 min | JSON 加载、检索、评分 | 结果区、感悟块样式 | 爬虫脚本、数据清洗说明 |
| 30—42 min | Agent、六模块、拒答 | 接 API、错误态 | 测试用例、演示脚本 |
| 42—52 min | 风险分级、双模式 | 模式切换、证据展示 | README、架构页 |
| 52—60 min | 打包回归 | 现场流程走查 | PPT 收尾、答辩分工 |

---

## 12. 常见问题

**Q1：没有安装 Maven？**
直接运行 `demo.bat` 或 `java -jar dist/crop-nutrition-agent-1.0.0.jar`，无需 Maven。需要改源码时，用 IDEA 打开 `pom.xml` 运行 `CropNutritionApplication`，或安装 Maven 3.9+ 后执行 `mvn spring-boot:run`。`start.bat` 会给出提示。

**Q2：8080 被占用？**
`application.yml` 修改 `server.port`，前端通过 `window.API_BASE` 指向新端口。

**Q3：页面中文乱码？**
项目文件均为 UTF-8；`start.bat` 已设置 `chcp 65001`。若 IDE 控制台乱码，不影响浏览器展示。

**Q4：没有 API Key 能演示吗？**
能，默认离线模式完整输出。API Key 只是增强摘要，不是业务前提。

**Q5：为什么置信度不是 100%？**
它表示本地证据匹配强度，不是实验室确诊概率；页面与 README 均明确提示需土壤/叶片检测复核。

**Q6：能否换成向量数据库？**
可以。`KnowledgeBaseService` 的检索接口与 `LocalVectorizer` 解耦，可替换为 Spring AI EmbeddingModel + Redis/Milvus/pgvector；比赛版选择零依赖本地实现以保证现场稳定。

---

## 13. 交付物

- [x] 可运行源码：爬虫、后端智能体、前端
- [x] 预构建可运行 jar（`dist/`，无 Maven 也能现场演示）
- [x] 本地缺素知识库（6 条结构化种子数据）
- [x] README 启动与演示说明
- [x] PPT 大纲（13 页，含创新点思路与效果）
- [x] 测试用例与真实 API 返回样例
- [x] 课程思政随业务输出
- [x] 一键启动 / 演示脚本

> 安全边界：本项目为教学与竞赛演示，不构成农艺处方。实际施肥须遵循当地测土配方、肥料登记标签与农技推广部门指导。

---

## 14. 上传 GitHub 并获取仓库链接

项目已配置 `.gitignore`、`.gitattributes` 和 GitHub Actions（`.github/workflows/build.yml`），可直接上传。详细图文步骤见 [GitHub发布指南.md](docs/GitHub发布指南.md)。

### 14.1 最快方式：GitHub Desktop

1. 下载并登录 <https://desktop.github.com/>；
2. `File → Add local repository`，选择 `D:\DSH\crop-nutrition-agent`，按提示 **create a repository**；
3. 填写提交说明，点击 **Commit to main**；
4. 点击 **Publish repository**，取消 “Keep this code private”；
5. 发布后点击 **View on GitHub**，地址即仓库链接。

### 14.2 命令行方式

```bat
cd /d D:\DSH\crop-nutrition-agent
git init
git config user.name "你的名字"
git config user.email "你的GitHub邮箱"
git add .
git commit -m "feat: 农作物缺素症识别与科学施肥建议智能体"
git branch -M main
git remote add origin https://github.com/你的用户名/crop-nutrition-agent.git
git push -u origin main
```

先在 <https://github.com/new> 创建 **Public** 空仓库（不要初始化 README），再执行 `git remote` 和 `git push`。

### 14.3 链接格式

```text
https://github.com/你的用户名/crop-nutrition-agent
```

仓库名不同则替换最后一段。比赛提交前确认仓库为 **Public**，评委无需登录即可访问。

### 14.4 说明

- `target/`、`.m2repo/`、`.tools/` 已被忽略；用 Git 命令行/GitHub Desktop 推送时会包含 `dist/` 中的预构建 jar，克隆后可直接 `demo.bat`。网页上传超过 25 MB 限制时，请把 jar 放到 Releases。
- 项目含 GitHub Actions，推送后自动执行 `mvn test`，可在仓库 **Actions** 页查看构建结果。
- GitHub Pages 只能托管静态页面，不能运行 Spring Boot。需要在线演示可用 Codespaces 或云服务器，详见发布指南。
- 当前环境未安装 Git，也没有你的 GitHub 账号授权，因此远程创建/推送需要你按上述步骤完成；本地项目已经整理好，无需再改代码。
