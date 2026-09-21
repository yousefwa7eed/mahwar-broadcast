# كتالوج المهارات — Catalogue of Skills

هذا ملف مرجعي يساعد موجه المهارات على اختيار المهارة الأنسب. يحتوي على كل مهارة مع:
- **الغرض**: ماذا تفعل
- **متى تُستخدم**: محفّزات الاستخدام
- **الناتج**: شكل النتيجة

> **ملاحظة مهمة:** المهارات المدرجة هنا مقسمة إلى قسمين:
> 1. **مهارات المشروع** (في `.agents/skills/`) — متاحة دائماً
> 2. **مهارات النظام الأوسع** (في `~/.claude/skills` و `~/.agents/skills`) — تشمل مهارات التطوير العامة والمخصصة

---

## أولاً: مهارات المشروع (في `.agents/skills/`)

### معالجة الملفات

| المهارة | الغرض | متى تُستخدم |
|---------|-------|-------------|
| **docx** | إنشاء/تعديل مستندات Word | طلب ملف `.docx` أو مستند نصي احترافي بفهرس وجداول وصور |
| **pdf** | كل عمليات PDF | طلب قراءة/دمج/تقسيم/تعبئة/تشفير PDF أو استخراج نصوص/صور منه |
| **pptx** | إنشاء/تعديل عروض PowerPoint | طلب عرض شرائح/عرض تقديمي/مجموعة شرائح |
| **xlsx** | إنشاء/تعديل ملفات Excel | طلب جدول/سبريدشيت/Excel/معالجة بيانات رقمية أو CSV |

### التصميم والبصريات

| المهارة | الغرض | متى تُستخدم |
|---------|-------|-------------|
| **canvas-design** | لوحات فنية ثابتة PNG/PDF | طلب بوستر/ملصق/قطعة فنية/تصميم ثابت بجودة فنية عالية |
| **frontend-design** | إرشاد تصميم واجهات ويب | طلب تصميم واجهة ويب مميزة - خطوط وتخطيط ولمسة إبداعية |
| **theme-factory** | قوالب ألوان/خطوط جاهزة | طلب "اجعله أنيقاً"/اختيار نظام ألوان لأي وثيقة أو عرض |
| **brand-guidelines** | هوية Anthropic الرسمية | طلب تطبيق هوية/شعار/ألوان محددة |
| **ui-ux-pro-max** | قاعدة بيانات UI/UX شاملة | طلب تصميم/مراجعة/تحسين واجهة مع تنويعات ستايلات وألوان وخطوط |

### الويب والتطبيقات

| المهارة | الغرض | متى تُستخدم |
|---------|-------|-------------|
| **web-artifacts-builder** | بناء مكونات React في HTML | طلب بناء واجهة/أدوات React معقدة في ملف واحد |
| **webapp-testing** | اختبار تطبيقات ويب محلية | طلب اختبار/تصحيب/فحص واجهة ويب محلية عبر المتصفح |
| **algorithmic-art** | فن تفاعلي بـ p5.js | طلب فن مولد/تفاعلي/خوارزمي بالكود |

### الهندسة البرمجية (مخصصة للمشروع)

| المهارة | الغرض | متى تُستخدم |
|---------|-------|-------------|
| **architecture** | توثيق قرارات هندسية (ADR) | طلب توثيق قرار معمارية/اختيار تقنية/تحليل مزايا وعيوب |
| **code-review** | مراجعة الكود | طلب مراجعة/فحص/تدقيق كود من الثغرات والأداء والجودة |
| **debug** | جلسة تصحيح منظمة | طلب إصلاح خطأ/تتبّع مشكلة/تحليل جذر العطل |

### إنشاء المحتوى والتكامل

| المهارة | الغرض | متى تُستخدم |
|---------|-------|-------------|
| **claude-api** | مرجع Claude API | طلب حول نماذج Claude/تسعير/streaming/tool use/MCP |
| **mcp-builder** | بناء خوادم MCP | طلب إنشاء خادم MCP يتيح للـ AI التواصل مع خدمات خارجية |
| **doc-coauthoring** | كتابة مستندات منظمة | طلب كتابة مقترح/تقرير/مواصفة/مستند تعاوني |
| **internal-comms** | قوالب اتصالات داخلية | طلب تحديث/نشرة/تقارير قيادية/أسئلة شائعة/تقرير حوادث |
| **slack-gif-creator** | إنشاء GIF لـ Slack | طلب صورة متحركة/جيفي مناسبة لـ Slack |
| **skill-creator** | إنشاء مهارات جديدة | طلب صناعة مهارة/تعديلها/قياس أدائها |
| **academy-guide** | توصيات دورات Claude | سؤال "كيف أتعلم استخدام Claude/كلود" |

### مساعدة وتوجيه

| المهارة | الغرض | متى تُستخدم |
|---------|-------|-------------|
| **discernment-nudge** | أسئلة متابعة نقدية | بعد إجابات جوهرية لفحص الحقائق والمنطق |
| **find-skill** | هذا الموجّه نفسه | قبل أي مهمة جوهرية لاختيار المهارة المثلى |
| **template-skill** | قالب فارغ | عند بناء مهارة جديدة من الصفر (مسودة) |

---

## ثانياً: مهارات النظام الأوسع (تطوير عام)

### تطوير الواجهات (Frontend)

| المهارة | الغرض |
|---------|-------|
| **react-expert / react-patterns** | بناء وتنقيح مكونات React |
| **react-performance** | تحسين أداء React/Next.js |
| **nextjs-developer** | تطبيقات Next.js App Router |
| **vue-expert / vue-patterns** | تطبيقات Vue 3 + Pinia + Nuxt |
| **angular-developer** | تطبيقات Angular 17+ |
| **frontend-patterns** | أساسيات التنمية الواجهية |
| **motion-ui / motion-patterns** | حركات وأنيميشن واجهات |
| **accessibility / frontend-a11y** | إتاحة الواجهات (WCAG) |

### تطوير الجوال (Mobile)

| المهارة | الغرض |
|---------|-------|
| **flutter-expert / dart-flutter-patterns** | تطبيقات Flutter |
| **react-native-expert** | تطبيقات React Native + Expo |
| **android-clean-architecture** | هندسة نظيفة في Android/KMP |
| **kotlin-specialist / compose-multiplatform-patterns** | Kotlin و Compose Multiplatform |
| **swift-expert** | تطبيقات iOS/macOS |

### الواجهات الخلفية (Backend)

| المهارة | الغرض |
|---------|-------|
| **python-pro / fastapi-expert** | تطوير Python و FastAPI |
| **django-expert / django-patterns** | تطبيقات Django |
| **nestjs-expert / nestjs-patterns** | تطبيقات NestJS |
| **spring-boot-engineer / java-architect** | تطبيقات Java Spring |
| **golang-pro / golang-patterns** | تطبيقات Go |
| **dotnet-core-expert / csharp-developer** | تطبيقات .NET/C# |
| **laravel-specialist / php-pro** | تطبيقات Laravel/PHP |
| **rails-expert** | تطبيقات Rails |
| **rust-engineer** | تطبيقات Rust |
| **node/javascript-pro** | تطبيقات Node.js/JavaScript |

### قواعد البيانات

| المهارة | الغرض |
|---------|-------|
| **sql-pro / postgres-pro** | تحسين الاستعلامات وقواعد البيانات |
| **database-optimizer** | تحسين أداء قواعد البيانات |
| **kotlin-exposed-patterns** | Exposed ORM |

### البنية والهندسة

| المهارة | الغرض |
|---------|-------|
| **architecture-designer** | تصميم بنى عالية المستوى |
| **microservices-architect** | بنى الخدمات المصغرة |
| **cloud-architect** | بنى سحابية AWS/Azure/GCP |
| **api-design / api-designer** | تصميم REST/GraphQL APIs |
| **hexagonal-architecture** | أسلوب برتس وأدابتورز |
| **contract-first** | تطوير قائم على العقود |

### الجودة والاختبار

| المهارة | الغرض |
|---------|-------|
| **code-reviewer / code-review** | مراجعة الكود والثغرات |
| **security-reviewer / secure-code-guardian** | مراجعة الأمان |
| **test-master / tdd-workflow** | كتابة الاختبارات و TDD |
| **playwright-expert / e2e-testing** | اختبارات E2E |
| **react-testing / python-testing** | اختبارات الوحدات |
| **browser-qa / webapp-testing** | فحص واجهات عبر المتصفح |
| **verification-loop / production-audit** | تحقق ما قبل النشر |

### البنية التحتية والدعم

| المهارة | الغرض |
|---------|-------|
| **devops-engineer / terraform-engineer** | CI/CD وبنية تحتية ككود |
| **kubernetes-specialist** | إدارة Kubernetes |
| **monitoring-expert / sre-engineer** | مراقبة وموثوقية |
| **docker** (ضمن devops) | حاويات |
| **git-workflow** | ممارسات git |

### سير العمل والميتا

| المهارة | الغرض |
|---------|-------|
| **skill-router (find-skill)** | اختيار أفضل مهارة |
| **code-tour / spec-miner** | استكشاف وفهم الكود |
| **council / the-fool** | اتخاذ قرارات مناقشة نقدية |
| **prompt-engineer / rag-architect** | تحسين البرومبت و RAG |
| **mcp-developer / mcp-server-patterns** | بناء خوادم/عملاء MCP |

---

## أمثلة قرارات سريعة

| الطلب | المهارة المثلى |
|-------|---------------|
| "حوّل هذا المستند إلى PDF" | `pdf` |
| "اصنع عرض شرائح عن منتجنا" | `pptx` |
| "راجع سكربت بايثون" | `python-pro` + `code-review` |
| "أبي تصميم واجهة تطبيق جوال" | `flutter-expert` + `ui-ux-pro-max` |
| "أصلح خطأ في كود React" | `react-expert` + `debug` |
| "اتبع أمان التطبيق الكامل" | `fullstack-guardian` |
| "أبي بوستر إعلاني جميل" | `canvas-design` |
| "اختبر تطبيقي الويب محلياً" | `webapp-testing` |
| "وثّق قرارنا المعماري" | `architecture` |
| "أبي شعار/هوية محددة" | `brand-guidelines` |
