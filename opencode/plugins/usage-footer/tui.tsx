import { Plugin } from "@opencode/plugin/tui"
import { createSignal } from "solid-js"

const MONTHLY_LIMIT_GO: Record<string, number> = {
  "deepseek-v4.1-flash": 60,
  "deepseek-v4-flash": 30,
  "deepseek-v4-flash-vision-exp": 15,
  "deepseek-v4-pro": 15,
  "glm-5.2": 60,
  "glm-5.3": 15,
  "glm-5.3-flash": 60,
  "gpt-5.6-luna": 15,
  "gpt-6-luna": 15,
  "grok-4.6": 15,
  "grok-4.7": 15,
  "hy3": 60,
  "hy4-preview": 30,
  "kimi-k2.6": 60,
  "kimi-k2.7-code": 60,
  "kimi-k3": 15,
  "longcat-2.0": 60,
  "mimo-v2.5": 60,
  "mimo-v2.5-pro": 15,
  "mimo-v2.6-flash": 60,
  "mimo-v2.6-pro": 15,
  "minimax-m2.7": 60,
  "minimax-m3": 60,
  "muse-spark-1.2-contributor": 60,
  "muse-spark-1.3-contributor": 60,
  "qwen3.7-plus": 60,
  "qwen3.8-flash": 30,
  "qwen3.8-max": 15,
}

const UNLIMITED_GO = new Set(["longcat-2.5-preview-free", "space-bunny-free"])

const formatPercent = (value: number) => `${Math.round(value)}%`

export default Plugin.define({
  id: "kaishi.usage-footer",
  setup(context) {
    const [now, setNow] = createSignal(Date.now())
    const timer = setInterval(() => setNow(Date.now()), 60_000)

    // 既存セッションのメッセージを読み、再起動前のローカル使用履歴も推定に含める。
    const location = context.location ?? context.data.location.default()
    void context.data.location.model.sync(location)
    const sessionIDs = new Set(
      context.data.session.list().flatMap((session) => context.data.session.family(session.id)),
    )
    for (const id of sessionIDs) {
      void context.data.session.message.sync(id)
    }

    const unregister = context.ui.slot({
      append: "prompt.footer",
      render: ({ sessionID }) => {
        if (!sessionID) return null

        const selected = context.ui.model.current()
        const messages = context.data.session.message.list(sessionID) ?? []
        const latest = [...messages]
          .reverse()
          .find((message) => message.role === "assistant" && message.tokens)
        const models = context.data.location.model.list(location) ?? []
        const model = models.find(
          (item) => item.providerID === selected?.providerID && item.id === selected?.id,
        )

        let contextLabel = "Context --"
        if (latest?.tokens && model?.limit?.context) {
          const used =
            latest.tokens.input +
            (latest.tokens.cache?.read ?? 0) +
            (latest.tokens.cache?.write ?? 0)
          contextLabel = `Context ${formatPercent((used / model.limit.context) * 100)}`
        }

        let goLabel = "Go 5h 推定 --"
        if (selected?.providerID === "opencode-go") {
          const monthlyLimit = MONTHLY_LIMIT_GO[selected.id]
          if (UNLIMITED_GO.has(selected.id)) {
            goLabel = "Go 5h 無制限"
          } else if (monthlyLimit) {
            const cutoff = now() - 5 * 60 * 60 * 1000
            const sessionIDs = new Set(
              context.data.session.list().flatMap((session) =>
                context.data.session.family(session.id),
              ),
            )
            let cost = 0
            for (const id of sessionIDs) {
              for (const message of context.data.session.message.list(id) ?? []) {
                if (
                  message.role !== "assistant" ||
                  message.providerID !== selected.providerID ||
                  message.modelID !== selected.id ||
                  !message.time?.completed ||
                  message.time.completed < cutoff
                ) {
                  continue
                }
                cost += message.cost ?? 0
              }
            }
            goLabel = `Go 5h 推定 ${formatPercent((cost / (monthlyLimit * 0.2)) * 100)}`
          }
        }

        return (
          <box>
            <text fg={context.theme.text.base}>{goLabel}  ·  {contextLabel}</text>
          </box>
        )
      },
    })

    return () => {
      clearInterval(timer)
      unregister()
    }
  },
})
