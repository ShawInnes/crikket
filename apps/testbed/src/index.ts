import { join } from "node:path"

const SDK_DIST = join(import.meta.dir, "../../../sdks/capture/dist")
const PUBLIC = join(import.meta.dir, "../public")
const PORT = 3002

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript",
  ".css": "text/css",
  ".map": "application/json",
}

function mime(path: string) {
  const dot = path.lastIndexOf(".")
  return MIME[path.slice(dot)] ?? "application/octet-stream"
}

Bun.serve({
  port: PORT,
  async fetch(req) {
    const { pathname } = new URL(req.url)

    if (pathname.startsWith("/sdk/")) {
      const file = Bun.file(join(SDK_DIST, pathname.slice(5)))
      if (await file.exists()) {
        return new Response(file, { headers: { "Content-Type": mime(pathname) } })
      }
    }

    const resolved = pathname === "/" ? "/index.html" : pathname
    const file = Bun.file(join(PUBLIC, resolved))
    if (await file.exists()) {
      return new Response(file, { headers: { "Content-Type": mime(resolved) } })
    }

    return new Response("Not found", { status: 404 })
  },
})

console.log(`[crikket] testbed → http://localhost:${PORT}`)
