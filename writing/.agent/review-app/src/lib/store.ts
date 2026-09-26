// Comments are stored per version. Through review_server.py they live on disk in
// writing/comments/v<N>.json; opened as a plain file, they fall back to the browser.
import type { ReviewComment } from "@/lib/anchor"

const local = (v: number) => `manuscript2_journal:comments:v${v}`

export async function hasDisk() {
  if (!location.protocol.startsWith("http")) return false
  try {
    return (await fetch("api/ping")).ok
  } catch {
    return false
  }
}

export async function loadComments(v: number, disk: boolean): Promise<ReviewComment[]> {
  if (!disk) return JSON.parse(localStorage.getItem(local(v)) ?? "[]")
  const r = await fetch(`api/comments/${v}`)
  return r.ok ? ((await r.json()).comments ?? []) : []
}

export async function saveComments(v: number, comments: ReviewComment[], disk: boolean) {
  if (!disk) return localStorage.setItem(local(v), JSON.stringify(comments))
  await fetch(`api/comments/${v}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ page: "manuscript2_journal.html", version: v, saved: new Date().toISOString(), comments }),
  })
}

export type WorkingDraft = { base: number; html: string; revision: string }

export async function loadDraft(): Promise<WorkingDraft> {
  const r = await fetch("api/draft", { cache: "no-store" })
  if (!r.ok) throw new Error("Could not load the working copy. Reload to try again.")
  return r.json()
}

export async function writeManuscript(action: "draft" | "versions" | "restore", revision: string, content: { html: string } | { v: number }) {
  const r = await fetch(`api/${action}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...content, revision }),
  })
  const result = await r.json()
  if (!r.ok) throw new Error(result.error || "Saving failed. Try again.")
  return result
}

// New versions appear while the page is open: poll the content file when served.
export async function fetchVersions(): Promise<string | null> {
  if (!location.protocol.startsWith("http")) return null
  try {
    const r = await fetch(".agent/manuscript2_journal_versions.js", { cache: "no-store" })
    return r.ok ? r.text() : null
  } catch {
    return null
  }
}

// Deletes one saved version (and its comments). The working copy is unaffected.
export async function deleteVersion(v: number) {
  const r = await fetch(`api/versions/${v}`, { method: "DELETE" })
  const result = await r.json()
  if (!r.ok) throw new Error(result.error || "Deleting failed. Try again.")
  return result
}
