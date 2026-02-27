import { serve } from "std/http/server.ts";
// import "https://deno.land/x/xhr@0.1.0/mod.ts";

// ─────────────────────────────────────────────
// ENV CHECK
// ─────────────────────────────────────────────
const QWEN_API_KEY = Deno.env.get("QWEN_API_KEY");
if (!QWEN_API_KEY) {
    throw new Error("QWEN_API_KEY environment variable is not set.");
}

// ─────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────
interface Message {
    role: "system" | "user" | "assistant";
    content: string;
}

interface RequestPayload {
    task: string;
    content?: string;
    params?: Record<string, unknown>;
    model?: string;
}

interface QwenBody {
    model: string;
    messages: Message[];
    response_format?: { type: string };
    temperature?: number;
}

// ─────────────────────────────────────────────
// PROMPTS  (النسخة المقوّاة)
// ─────────────────────────────────────────────
const PROMPTS = {

    // ── 🎓 TUTOR ────────────────────────────────
    tutor: `أنت "المعلم الذكي"، مساعد تعليمي ذكي على منصة EdSentre.

## هويتك:
- متخصص في مساعدة طلاب الإعدادية والثانوية في فهم المناهج المصرية.
- بتتكلم بلهجة مصرية ودودة، زي صاحب بيشرح لصاحبه — مش محاضر رسمي.
- **لا تذكر اسمك أبداً إلا لو سألك الطالب مباشرة "من أنت؟" أو "ما اسمك؟".**

## طريقة شرحك — اتبع الترتيب ده دايماً:
1. **الفكرة الأساسية** في جملة واحدة أو اتنين بالكتير.
2. **مثال حقيقي** من حياة الطالب اليومية يوضّح الفكرة.
3. **الشرح التفصيلي** لو الموضوع يحتاج — خطوات مرقمة أو نقاط واضحة.
4. **سؤال تأكيد واحد** في الآخر تتأكد إن الطالب فاهم.

## قواعد الرد:
- 🚫 **ممنوع** تبدأ بـ: "بالتأكيد!" / "سؤال رائع!" / "يسعدني مساعدتك" أو أي عبارة فارغة.
- 🚫 **ممنوع** تكرر كلام الطالب في بداية ردك.
- 🚫 **ممنوع** تجاوب على أسئلة خارج المجال التعليمي (سياسة، دين، أخبار، علاقات شخصية).
  → لو سألك، قول: "ده مش تخصصي — أنا هنا عشان أساعدك في دراستك! 📚 في حاجة تانية عايز تفهمها؟"
- 🚫 **ممنوع** تديه الإجابة مباشرة في مسائل الواجب — وجّهه خطوة خطوة.
- ✅ استخدم **Markdown**: bold للمصطلحات، قوائم مرقمة، وكود للبرمجة.
- ✅ Emoji بشكل طبيعي ومحدود (مش في كل كلمة).
- ✅ الرد مختصر ومركّز — لا تطوّل إلا لو الموضوع فعلاً معقد.
- ✅ لو الطالب مش فاهمك، اشرح بطريقة مختلفة وبمثال تاني.

## أمثلة على الأسلوب الصح:
سؤال: "إيه هو التفاضل؟"
✅ ردّ صح: "التفاضل بيجاوب على سؤال: بتتغير بأي سرعة؟ 📈
تخيّل عداد سرعة العربية — لما بتشوف 80 كيلو، ده مش المسافة الكلية، ده **معدّل التغير لحظياً**. ده بالظبط معنى المشتقة.
إيه اللي بيحيّرك أكتر، المفهوم ولا طريقة الحساب؟"

سؤال: "احسبلي الواجب ده"
✅ ردّ صح: "مش هحلّهولك، بس هساعدك تحلّه! 😄
ابدأ معايا: إيه أول خطوة بتفكر فيها؟"`,

    // ── 👩‍🏫 TEACHER ASSISTANT ────────────────────
    teacherAssistant: `أنت "مساعد المعلم"، خبير تربوي ذكي على منصة EdSentre.

## دورك:
شريك المعلم في مهامه اليومية:
- ✍️ كتابة رسائل احترافية لأولياء الأمور جاهزة للإرسال.
- 💡 اقتراح استراتيجيات تدريس مبتكرة مع خطوات تطبيق واضحة.
- 🧠 تحليل المشكلات السلوكية وتقديم حلول تربوية عملية.
- 📝 صياغة أسئلة امتحانات وواجبات متوازنة.

## أسلوبك:
- **مهني وداعم** — بتفهم ضغط المعلم ومش بتحاضر عليه.
- اللغة: فصحى مبسطة أو عامية مهذبة حسب السياق.
- **مباشر** — ابدأ بالحل أو المطلوب مباشرة بدون مقدمات.

## قواعد الرد:
- 🚫 **ممنوع** تبدأ بـ: "بالطبع!" / "يسعدني!" / "سؤال رائع!" أو أي عبارة فارغة.
- 🚫 **ممنوع** تقدم نصائح طبية أو قانونية — ركّز على الجانب التربوي فقط.
- 🚫 **ممنوع** تتجاوب على طلبات خارج المجال التعليمي والتربوي.
- ✅ لو طُلبت **رسالة لولي أمر**: اكتبها كاملة وجاهزة للنسخ فوراً.
- ✅ لو طُلبت **استراتيجية تدريس**: قدّم 2-3 خيارات عملية مع خطوات التطبيق.
- ✅ لو طُلب **تحليل مشكلة سلوكية**: حدد السبب المحتمل ثم اقترح الحل.
- ✅ اختم دايماً بعرض مساعدة إضافية لو في تفاصيل يحتاجها.

## حدودك:
لو سألك المعلم عن موضوع خارج نطاقك، وضّح بلطف:
"ده خارج تخصصي التربوي، بس لو في حاجة تانية تخص طلابك أو الفصل، أنا موجود!"`,

    // ── 📋 EXAMINER ──────────────────────────────
    examiner: `أنت خبير تربوي متخصص في تصميم الامتحانات والتقييم التربوي.

## مهمتك:
إنشاء أسئلة امتحانية دقيقة ومتوازنة بناءً على المحتوى المُقدَّم، مع مراعاة:
- **تصنيف بلوم**: التذكر، الفهم، التطبيق، التحليل، التقييم، الإبداع.
- التوزيع المتوازن على مستويات الصعوبة المطلوبة.
- الوضوح التام في الصياغة — لا غموض ولا احتمالين.

## معايير جودة الأسئلة:
- **MCQ**: إجابة صحيحة واحدة قاطعة. الخيارات الخاطئة (distractors) تعكس أخطاء شائعة حقيقية وتبدو منطقية.
- **صح وغلط**: العبارات لا تحتمل تأويلاً — صح بالكامل أو غلط بالكامل.
- **مقالي/قصير**: السؤال يحدد بوضوح ما هو المطلوب من الطالب.
- الدرجات تتناسب مع صعوبة السؤال ووقت الإجابة المتوقع.

## قواعد المخرج:
- 🚫 **JSON فقط** — لا نص قبله، لا نص بعده، لا markdown، لا شرح.
- 🚫 لا تكرر نفس المعلومة في أسئلة مختلفة.
- ✅ الأسئلة مرتبطة بالمحتوى المُقدَّم حصراً — لا تخترع معلومات.
- ✅ التنسيق ملتزم تماماً بالـ schema المطلوب.`,

    // ── 📊 ANALYST ───────────────────────────────
    analyst: `أنت محلل بيانات تعليمي متخصص في تقييم أداء الطلاب.

## مهمتك:
تحليل البيانات المقدمة بموضوعية علمية لاستخراج:
- **نقاط القوة** التي يجب تعزيزها.
- **نقاط الضعف** مع تحديد السبب المحتمل (فجوة معرفية / مفهوم خاطئ / تراجع مستمر).
- **توصيات علاجية** قابلة للتطبيق الفعلي داخل الفصل.

## معايير تحديد الـ severity:
- **high**: درجة أقل من 50%، أو تراجع مستمر في 3 تقييمات متتالية أو أكثر.
- **medium**: درجة بين 50% و70%، أو أداء غير منتظم (تذبذب كبير).
- **low**: درجة فوق 70% لكن أقل من المعدل العام للطالب في باقي المواد.

## قواعد المخرج:
- 🚫 **JSON فقط** — لا نص قبله، لا نص بعده، لا markdown، لا شرح.
- 🚫 لا تستنتج أكثر مما تدل عليه البيانات بوضوح.
- ✅ كل insight يحتوي على suggestion عملية وقابلة للقياس.
- ✅ الـ overall_summary: 2-3 جمل مركّزة فقط تلخص الصورة الكاملة.
- ✅ التنسيق ملتزم تماماً بالـ schema المطلوب.`,
};

// ─────────────────────────────────────────────
// CORS
// ─────────────────────────────────────────────
const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

/** Inject system prompt safely into a history array */
function buildMessagesWithHistory(
    history: Message[],
    systemPrompt: string
): Message[] {
    const messages = [...history];
    if (messages[0]?.role === "system") {
        messages[0] = { role: "system", content: systemPrompt };
    } else {
        messages.unshift({ role: "system", content: systemPrompt });
    }
    return messages;
}

/** Safe substring — handles undefined/null gracefully */
function safeSubstring(text: unknown, max: number): string {
    if (typeof text !== "string") return "";
    return text.substring(0, max);
}

/** Call Qwen API with a 60-second timeout */
async function callQwen(
    body: QwenBody
): Promise<{ content: string; usage: unknown }> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60_000);

    try {
        console.log(`👉 [callQwen] Starting fetch... Model: ${body.model}`);
        const start = Date.now();
        const resp = await fetch(
            "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
            {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${QWEN_API_KEY}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(body),
                signal: controller.signal,
            }
        );
        console.log(`👉 [callQwen] Response received. Status: ${resp.status} in ${Date.now() - start}ms`);

        if (!resp.ok) {
            const errText = await resp.text();
            console.error(`🚨 [callQwen] Error: ${errText}`);
            throw new Error(`Qwen API HTTP ${resp.status}: ${errText}`);
        }

        const data = await resp.json();
        console.log("👉 [callQwen] Data parsed successfully");

        if (!data.choices?.length) {
            console.error(`🚨 [callQwen] No choices: ${JSON.stringify(data)}`);
            throw new Error(`Qwen API returned no choices: ${JSON.stringify(data)}`);
        }

        return {
            content: data.choices[0].message.content,
            usage: data.usage,
        };
    } finally {
        clearTimeout(timeout);
    }
}

// ─────────────────────────────────────────────
// SERVER
// ─────────────────────────────────────────────
serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    // 🔍 Lightweight Ping (GET or POST) - No body parsing required
    const url = new URL(req.url);
    if (url.searchParams.get("t") === "ping") {
        console.log("👉 [Ping] Fast pong (no body parse)");
        return new Response("pong", { headers: corsHeaders });
    }

    try {
        const payload: RequestPayload = await req.json();
        console.log("👉 [Request] Payload received:", JSON.stringify(payload).substring(0, 100));

        // 🔍 Ping Test
        if (payload.content === "ping" || payload.task === "ping") {
            console.log("👉 [Ping] Returning pong");
            return new Response(JSON.stringify({ content: "pong", session_id: "test" }), {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const {
            task,
            content = "",
            params = {},
            model: overrideModel,
        } = payload;

        let messages: Message[] = [];
        let model = overrideModel || "qwen-plus";
        let jsonMode = false;
        let temperature: number | undefined = undefined;

        // ── Task Router ────────────────────────────
        switch (task) {

            // ── Student Tasks ──────────────────────
            case "studentChatTutor": {
                console.log("👉 [studentChatTutor] Started");
                temperature = 0.7; // ودود لكن مركّز
                const history = params.messages as Message[] | undefined;
                if (history?.length) {
                    messages = buildMessagesWithHistory(history, PROMPTS.tutor);
                    if (content) messages.push({ role: "user", content });
                } else {
                    messages = [
                        { role: "system", content: PROMPTS.tutor },
                        { role: "user", content },
                    ];
                }
                console.log("👉 [studentChatTutor] Messages prepared:", JSON.stringify(messages).substring(0, 200) + "...");
                break;
            }

            case "studentCreateFlashcards": {
                const count = (params.count as number) || 5;
                model = content.length > 4000 ? "qwen-long" : "qwen-plus";
                jsonMode = true;
                temperature = 0.3; // دقيق ومنتظم
                messages = [
                    {
                        role: "system",
                        content:
                            "أنت خبير في إنشاء بطاقات استذكار (Flashcards) تعليمية. المخرج JSON فقط بدون أي نص إضافي.",
                    },
                    {
                        role: "user",
                        content: `أنشئ بالضبط ${count} بطاقات استذكار من النص التالي.
قواعد:
- الـ front: سؤال أو مصطلح واضح.
- الـ back: إجابة مختصرة ودقيقة (جملة أو اتنين بالكتير).
- لا تكرر نفس المعلومة في بطاقتين.

التنسيق JSON المطلوب حصراً:
{ "items": [{"front": "...", "back": "..."}] }

النص:
${safeSubstring(content, 10000)}`,
                    },
                ];
                break;
            }

            // ── Teacher Tasks ──────────────────────
            case "teacherChatAssistant": {
                temperature = 0.5; // مهني ومتسق
                const history = params.messages as Message[] | undefined;
                if (history?.length) {
                    messages = buildMessagesWithHistory(
                        history,
                        PROMPTS.teacherAssistant
                    );
                    if (content) messages.push({ role: "user", content });
                } else {
                    messages = [
                        { role: "system", content: PROMPTS.teacherAssistant },
                        { role: "user", content },
                    ];
                }
                break;
            }

            case "teacherGenerateExam": {
                model = "qwen-max";
                jsonMode = true;
                temperature = 0.2; // دقة عالية جداً
                const qCount = (params.questionCount as number) || 10;
                const diff = (params.difficulty as string) || "medium";
                const examType = (params.examType as string) || "exam";
                const subject = (params.subject as string) || "عام";
                const gradeLevel = (params.gradeLevel as string) || "عام";

                messages = [
                    { role: "system", content: PROMPTS.examiner },
                    {
                        role: "user",
                        content: `أنشئ امتحاناً من نوع "${examType}" للمادة: ${subject} | الصف: ${gradeLevel}.
عدد الأسئلة: ${qCount} | مستوى الصعوبة: ${diff}.

المحتوى المرجعي (التزم به حصراً):
${safeSubstring(content, 15000)}

التنسيق JSON المطلوب حصراً:
{
  "title": "عنوان الامتحان",
  "subject": "${subject}",
  "grade_level": "${gradeLevel}",
  "total_marks": 100,
  "estimated_time_minutes": 45,
  "questions": [
    {
      "id": 1,
      "type": "multiple_choice",
      "bloom_level": "understanding",
      "question": "نص السؤال",
      "options": ["A", "B", "C", "D"],
      "correct_answer": 0,
      "explanation": "لماذا هذه الإجابة صحيحة (جملة واحدة)",
      "difficulty": "medium",
      "marks": 2
    }
  ]
}

ملاحظات:
- type يكون: multiple_choice أو true_false أو short_answer.
- bloom_level يكون: remember / understand / apply / analyze / evaluate / create.
- correct_answer: index (0-3) للـ MCQ، "true"/"false" للصح والغلط، أو نص للمقالي.
- وزّع الأسئلة على مستويات بلوم المختلفة.`,
                    },
                ];
                break;
            }

            case "teacherGenerateAssignment": {
                jsonMode = true;
                temperature = 0.3;
                const topic = (params.topic as string) || "عام";
                const questionCount = (params.questionCount as number) || 5;

                messages = [
                    {
                        role: "system",
                        content:
                            "أنت مساعد للمعلم لإنشاء واجبات منزلية تعليمية عالية الجودة. المخرج JSON فقط.",
                    },
                    {
                        role: "user",
                        content: `أنشئ واجباً منزلياً عن: ${topic}.
عدد الأسئلة: ${questionCount}.

المحتوى المرجعي:
${safeSubstring(content, 10000)}

التنسيق JSON المطلوب حصراً:
{
  "title": "عنوان الواجب",
  "topic": "${topic}",
  "items": [
    {
      "id": 1,
      "question": "نص السؤال",
      "answer": "الإجابة النموذجية",
      "difficulty": "easy"
    }
  ]
}`,
                    },
                ];
                break;
            }

            case "teacherAnalyzeClassPerformance": {
                model = "qwen-max";
                jsonMode = true;
                temperature = 0.1; // أعلى دقة ممكنة للتحليل
                messages = [
                    { role: "system", content: PROMPTS.analyst },
                    {
                        role: "user",
                        content: `حلّل أداء الطالب التالي وحدد نقاط القوة والضعف بدقة.

البيانات:
${safeSubstring(content, 15000)}

التنسيق JSON المطلوب حصراً:
{
  "insights": [
    {
      "subject": "اسم المادة",
      "type": "weakness",
      "severity": "high",
      "message": "وصف واضح للمشكلة بناءً على البيانات",
      "suggestion": "خطوة عملية ومحددة للتحسين"
    }
  ],
  "overall_summary": "ملخص عام في 2-3 جمل",
  "priority_action": "أهم إجراء يجب اتخاذه فوراً"
}

ملاحظة: type يكون: weakness أو strength أو warning.`,
                    },
                ];
                break;
            }

            // ── Default ────────────────────────────
            default: {
                temperature = 0.5;
                messages = [
                    { role: "system", content: PROMPTS.tutor },
                    { role: "user", content },
                ];
            }
        }

        // ── Build Qwen Body ────────────────────────
        const qwenBody: QwenBody = { model, messages };
        if (jsonMode) {
            qwenBody.response_format = { type: "json_object" };
        }
        if (temperature !== undefined) {
            qwenBody.temperature = temperature;
        }

        const result = await callQwen(qwenBody);

        return new Response(JSON.stringify(result), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    } catch (error) {
        const message =
            error instanceof Error ? error.message : "Unknown error occurred";
        return new Response(JSON.stringify({ error: message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});
