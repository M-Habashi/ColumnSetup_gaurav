import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import { createPortal } from "react-dom"
import {
  CheckIcon,
  ChevronDownIcon,
  ChevronUpIcon,
  CloudCheckIcon,
  CloudOffIcon,
  CopyIcon,
  FileTextIcon,
  HistoryIcon,
  ListTreeIcon,
  LoaderIcon,
  MessageSquareIcon,
  MessageSquarePlusIcon,
  MoonIcon,
  PencilIcon,
  RotateCcwIcon,
  RefreshCwIcon,
  SaveIcon,
  SparklesIcon,
  SunIcon,
  Trash2Icon,
  XIcon,
} from "lucide-react"

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { Item, ItemActions, ItemContent, ItemGroup } from "@/components/ui/item"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Separator } from "@/components/ui/separator"
import { Textarea } from "@/components/ui/textarea"
import { Toggle } from "@/components/ui/toggle"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { useTheme } from "@/components/theme-provider"
import { type ReviewComment, draftFromRange, paintComments } from "@/lib/anchor"
import { compare } from "@/lib/diff"
import { applySuggestion, deleteVersion, discardSuggestion, fetchVersions, hasDisk, loadComments, pollSuggestion, saveComments, startSuggestion, loadDraft, writeManuscript, type Suggestion, type WorkingDraft } from "@/lib/store"
import { acceptedHtml, lockBlocks } from "@/lib/track"
import { EDITABLE_BLOCKS, baseWords, insertedRanges, paragraphDocument, updatedParagraph } from "@/lib/paragraph-editor"
import { cn } from "@/lib/utils"

type Version = { v: number; date: string; note: string; html: string; author?: "user" }
declare global {
  interface Window {
    MANUSCRIPT_VERSIONS?: Version[]
    MANUSCRIPT_WORD?: Record<string, string>
  }
}
type Panel = "comments" | "history" | null
type Save = "saved" | "saving" | "local"

function paragraphTarget(element: Element) {
  const height = Math.max(96, Math.min(480, element.getBoundingClientRect().height + 32))
  const font = getComputedStyle(element).font
  const host = element.cloneNode(false) as HTMLElement
  host.setAttribute("data-editor-host", "")
  const source = paragraphDocument(element.innerHTML)
  element.replaceWith(host)
  return { element, host, source, height, font }
}

// One counting rule everywhere: equations, figure drawings and references are not words.
const NOT_WORDS = "math, svg, .references"

function countWords(content: DocumentFragment) {
  content.querySelectorAll(NOT_WORDS).forEach((e) => e.remove())
  return content.textContent?.match(/\S+/g)?.length ?? 0
}

function wordCount(html: string) {
  const t = document.createElement("template")
  t.innerHTML = html
  return countWords(t.content)
}

function selectionWords(sel: Selection | null) {
  if (!sel || sel.isCollapsed || !sel.rangeCount) return 0
  const r = sel.getRangeAt(0)
  const inside = r.commonAncestorContainer
  if ((inside instanceof Element ? inside : inside.parentElement)?.closest(NOT_WORDS)) return 0
  return countWords(r.cloneContents())
}

function Hint({ text, children }: { text: string; children: React.ReactElement }) {
  return (
    <Tooltip>
      <TooltipTrigger render={children} />
      <TooltipContent>{text}</TooltipContent>
    </Tooltip>
  )
}

export function App() {
  const { theme, setTheme } = useTheme()
  const dark =
    theme === "dark" ||
    (theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches)

  const [versions, setVersions] = useState<Version[]>(window.MANUSCRIPT_VERSIONS ?? [])
  const [word, setWord] = useState(window.MANUSCRIPT_WORD ?? {})
  const last = versions.length - 1
  // -1 is the working copy; numbered versions are immutable snapshots.
  const [selected, setSelected] = useState(-1)
  const [working, setWorking] = useState<WorkingDraft | null>(null)
  const [busy, setBusy] = useState(false)
  const busyRef = useRef(false)
  const [manuscriptNotice, setManuscriptNotice] = useState("")
  const [compareWith, setCompareWith] = useState<number | null>(null)
  // Phones start with the manuscript uncovered; the panel is a full-width overlay there.
  const [panel, setPanel] = useState<Panel>(window.innerWidth >= 640 ? "comments" : null)
  const [disk, setDisk] = useState<boolean | null>(null)
  const [save, setSave] = useState<Save>("local")
  const [comments, setComments] = useState<ReviewComment[]>([])
  const [loadedFor, setLoadedFor] = useState<number | null>(null)
  const [activeId, setActiveId] = useState<string | null>(null)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [order, setOrder] = useState<string[]>([])
  const [eqHosts, setEqHosts] = useState<{ host: Element; id: string }[]>([])
  const [stats, setStats] = useState({ added: 0, deleted: 0, changes: 0 })
  const [changeAt, setChangeAt] = useState(-1)
  const [addTop, setAddTop] = useState<number | null>(null)
  const [citePop, setCitePop] = useState<{ top: number; left: number; html: string } | null>(null)
  const citeTimer = useRef(0)
  const [selectedWords, setSelectedWords] = useState(0)
  const [editing, setEditing] = useState(false)
  const [deleting, setDeleting] = useState<number | null>(null)
  const [dirty, setDirty] = useState(false)
  const [editTarget, setEditTarget] = useState<ReturnType<typeof paragraphTarget> | null>(null)
  const [draftDirty, setDraftDirty] = useState(false)
  const [editorNotice, setEditorNotice] = useState("")
  const frameRef = useRef<HTMLIFrameElement>(null)
  const pendingParagraphRef = useRef<number | null>(null)
  const editingRef = useRef(false)
  editingRef.current = editing
  // One comment at a time can be applied by the agent; its result is shown as a diff in place.
  const [suggest, setSuggest] = useState<(Suggestion & { commentId: string; version: number; prompt: string }) | null>(null)
  const suggestHtml = suggest?.status === "done" ? suggest.html : undefined

  const commentsRef = useRef(comments)
  const loadedRef = useRef<ReviewComment[] | null>(null)
  commentsRef.current = comments
  const docRef = useRef<HTMLElement>(null)
  const paperRef = useRef<HTMLDivElement>(null)
  const rangeRef = useRef<Range | null>(null)
  const cardRefs = useRef(new Map<string, HTMLElement>())

  const version = useMemo(() => selected === -1
    ? { ...versions[last], html: working?.html ?? versions[last]?.html, author: "user" as const }
    : versions[selected], [versions, selected, last, working])
  // Version index -1 is the working copy, listed and compared like any saved version.
  const htmlOf = (i: number) => (i === -1 ? working?.html ?? versions[last]?.html ?? "" : versions[i].html)
  const comparing = compareWith !== null
  const reviewing = !comparing && !editing && loadedFor === version?.v
  const canEdit = disk === true && working !== null && !comparing && selected === -1 && !busy
  const anchorKey = comments.map((c) => c.id).join()
  const reviewAnchors = reviewing ? anchorKey : ""
  const counts = useMemo(() => versions.map((v) => wordCount(v.html)), [versions])

  useEffect(() => {
    void hasDisk().then(async (available) => {
      setDisk(available)
      if (available) {
        try { setWorking(await loadDraft()) }
        catch (error) { setManuscriptNotice(String(error)) }
      }
    })
  }, [])

  // Load the selected version's comments, then save every change back automatically.
  useEffect(() => {
    if (disk === null || !version) return
    setLoadedFor(null)
    setActiveId(null)
    setEditingId(null)
    loadComments(version.v, disk).then((cs) => {
      loadedRef.current = cs
      setComments(cs)
      setLoadedFor(version.v)
      setSave(disk ? "saved" : "local")
    })
  }, [disk, version?.v]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (loadedFor === null || disk === null || comments === loadedRef.current) return
    if (disk) setSave("saving")
    const t = setTimeout(
      () => saveComments(loadedFor, comments, disk).then(() => setSave(disk ? "saved" : "local")),
      400
    )
    return () => clearTimeout(t)
  }, [comments]) // eslint-disable-line react-hooks/exhaustive-deps

  // Pick up new versions as soon as the content file changes.
  useEffect(() => {
    let seen: string | null = null
    const id = setInterval(async () => {
      if (editingRef.current || busyRef.current || document.hidden) return
      const text = await fetchVersions()
      if (!text || editingRef.current || busyRef.current) return
      if (seen !== null && text !== seen) {
        const draft = await loadDraft().catch(() => null)
        if (editingRef.current || busyRef.current) return
        new Function(text)()
        const vs = window.MANUSCRIPT_VERSIONS ?? []
        setVersions(vs)
        if (draft) setWorking(draft)
        setWord(window.MANUSCRIPT_WORD ?? {})
      }
      seen = text
    }, 3000)
    return () => clearInterval(id)
  }, [])

  // Render the document: the selected version, or its comparison with another one.
  useLayoutEffect(() => {
    const doc = docRef.current!
    if (!version) return
    if (suggestHtml && compareWith === null) {
      const r = compare(version.html, suggestHtml)
      doc.replaceChildren(...r.nodes)
      setStats(r)
    } else if (compareWith !== null) {
      const r = compare(htmlOf(compareWith), version.html)
      doc.replaceChildren(...r.nodes)
      setStats(r)
    } else doc.innerHTML = version.html
    doc.removeAttribute("contenteditable")
    doc.toggleAttribute("data-editing", editing)
    if (editing) {
      const index = pendingParagraphRef.current
      if (index !== null) {
        const element = doc.querySelectorAll(EDITABLE_BLOCKS)[index]
        if (element) setEditTarget(paragraphTarget(element))
        pendingParagraphRef.current = null
      }
    }
    doc.dataset.author = editing || (compareWith !== null && version.author === "user") ? "user" : ""
    setChangeAt(-1)
    setEqHosts(
      editing ? [] : Array.from(doc.querySelectorAll(".equation")).map((eq, k) => {
        const host = document.createElement("span")
        host.className = "eq-copy"
        eq.insertBefore(host, eq.querySelector(".eqno"))
        return { host, id: eq.id || `eq${k + 1}` }
      })
    )
    if (reviewing && !suggestHtml) setOrder(paintComments(doc, commentsRef.current).order)
    if (suggestHtml) doc.querySelector("ins, del")?.scrollIntoView({ block: "center", behavior: "smooth" })
  }, [version, versions, compareWith, reviewing, reviewAnchors, editing, suggestHtml])

  // Follow a running suggestion until the agent finishes.
  useEffect(() => {
    if (suggest?.status !== "running") return
    const t = setInterval(async () => {
      try {
        const r = await pollSuggestion(suggest.id)
        if (r.status !== "running") setSuggest((s) => (s && s.id === r.id ? { ...s, ...r } : s))
      } catch (error) {
        setSuggest((s) => s && { ...s, status: "error", error: String(error) })
      }
    }, 2000)
    return () => clearInterval(t)
  }, [suggest?.id, suggest?.status])

  // Theme changes do not reload the frame or reset native undo.
  useEffect(() => {
    const body = frameRef.current?.contentDocument?.body
    if (body) paintEditorColours(body)
  }, [dark, editTarget])

  function paintEditorColours(body: HTMLElement) {
    const styles = getComputedStyle(docRef.current!)
    body.style.color = styles.color
    body.style.setProperty("--user-ins", styles.getPropertyValue("--user-ins").trim() || "#1f8a45")
  }

  function openParagraph(element: Element) {
    if (busyRef.current) return
    if (draftDirty) {
      setEditorNotice("Update or cancel this paragraph before choosing another.")
      return
    }
    if (editTarget) editTarget.host.replaceWith(editTarget.element)
    setEditTarget(paragraphTarget(element))
    setDraftDirty(false)
    setEditorNotice("")
  }

  function prepareParagraph() {
    const frame = frameRef.current
    const editor = frame?.contentDocument?.getElementById("editor")
    if (!editor) return
    paintEditorColours(frame!.contentDocument!.body)
    if (editTarget?.font) frame!.contentDocument!.body.style.font = editTarget.font
    lockBlocks(editor)
    // Colour only the words typed since opening, via a CSS highlight (no DOM changes).
    const win = frame!.contentWindow as (Window & typeof globalThis) | null
    const base = baseWords(editor)
    let timer = 0
    editor.addEventListener("input", () => {
      clearTimeout(timer)
      timer = window.setTimeout(() => {
        if (win?.CSS?.highlights) win.CSS.highlights.set("user-ins", new win.Highlight(...insertedRanges(editor, base)))
      }, 120)
    })
    editor.addEventListener("input", () => {
      setDraftDirty(true)
      setDirty(true)
    }, { once: true })
    editor.focus()
  }

  function paragraphHtml() {
    if (!editing) return working!.html
    const editor = frameRef.current?.contentDocument?.getElementById("editor")
    const copy = docRef.current!.cloneNode(true) as HTMLElement
    if (editTarget) {
      copy.querySelector("[data-editor-host]")?.replaceWith(editor
        ? updatedParagraph(editTarget.element, editor) : editTarget.element.cloneNode(true))
    }
    return acceptedHtml(copy)
  }

  async function persist(action: "draft" | "versions" | "restore", restoreVersion?: number) {
    if (!working || busyRef.current) return
    busyRef.current = true
    setBusy(true)
    setManuscriptNotice("")
    const editor = frameRef.current?.contentDocument?.getElementById("editor")
    // Preserve the frame, draft text, and native undo if the disk write fails.
    if (editor) editor.contentEditable = "false"
    try {
      const result = await writeManuscript(action, working.revision,
        action === "restore" ? { v: restoreVersion! } : { html: paragraphHtml() })
      if (editTarget) editTarget.host.replaceWith(editTarget.element)
      setEditTarget(null)
      setDraftDirty(false)
      setDirty(false)
      setEditorNotice("")
      setWorking(result.draft)
      setEditing(false)
      if (action !== "draft") {
        window.MANUSCRIPT_VERSIONS = result.versions
        setVersions(result.versions)
        setCompareWith(null)
        setSelected(-1)
        setPanel("history")
      }
      setManuscriptNotice(action === "draft" ? "Paragraph saved" : action === "restore"
        ? `Reverted to v${restoreVersion}. Working copy saved.`
        : `Saved as v${result.versions.at(-1).v}`)
    } catch (error) {
      setManuscriptNotice(error instanceof Error ? error.message : "Saving failed. Try again.")
    } finally {
      if (editor) editor.contentEditable = "true"
      busyRef.current = false
      setBusy(false)
    }
  }

  function updateParagraph() {
    void persist("draft")
  }

  function cancelParagraph() {
    if (busyRef.current) return
    if (editTarget) editTarget.host.replaceWith(editTarget.element)
    setEditTarget(null)
    setDraftDirty(false)
    setEditorNotice("")
    setDirty(false)
  }

  function startEditing() {
    if (busyRef.current) return
    cancelParagraph()
    setDirty(false)
    setSelectedWords(0)
    setAddTop(null)
    setEditing(true)
  }

  function closeParagraph() {
    cancelParagraph()
    setEditing(false)
  }

  async function removeVersion(i: number) {
    setDeleting(null)
    try {
      const result = await deleteVersion(versions[i].v)
      window.MANUSCRIPT_VERSIONS = result.versions
      setVersions(result.versions)
      setWorking(result.draft)
      setCompareWith(null)
      setSelected(-1)
      setManuscriptNotice(`Deleted v${versions[i].v}`)
    } catch (error) {
      setManuscriptNotice(error instanceof Error ? error.message : "Deleting failed. Try again.")
    }
  }

  function saveEdits() {
    void persist("versions")
  }

  useEffect(() => {
    const doc = docRef.current!
    doc.querySelectorAll(".cmt.active").forEach((m) => m.classList.remove("active"))
    if (activeId)
      doc.querySelectorAll(`mark[data-comment="${activeId}"]`).forEach((m) => m.classList.add("active"))
  }, [activeId, anchorKey, reviewing])

  useEffect(() => {
    if (editing) return
    const onSelection = () => {
      const sel = getSelection()
      setSelectedWords(selectionWords(sel))
      if (!sel || sel.isCollapsed) setAddTop(null)
      // Touch selection fires no mouseup, so place the add button as the selection changes.
      else if (matchMedia("(pointer: coarse)").matches) onDocMouseUp()
    }
    document.addEventListener("selectionchange", onSelection)
    return () => document.removeEventListener("selectionchange", onSelection)
  }, [editing, reviewing])

  const sorted = useMemo(() => {
    const rank = (c: ReviewComment) => {
      const k = order.indexOf(c.id)
      return k < 0 ? Infinity : k
    }
    return [...comments].sort((a, b) => rank(a) - rank(b))
  }, [comments, order])

  function onDocMouseUp() {
    const sel = getSelection()
    if (!reviewing || !sel || sel.isCollapsed || !docRef.current!.contains(sel.anchorNode)) return
    const r = sel.getRangeAt(0)
    const line = Array.from(r.getClientRects()).pop() ?? r.getBoundingClientRect()
    rangeRef.current = r.cloneRange()
    setAddTop(line.top - paperRef.current!.getBoundingClientRect().top + line.height / 2 - 16)
  }

  function addComment() {
    const draft = rangeRef.current && draftFromRange(docRef.current!, rangeRef.current)
    getSelection()?.removeAllRanges()
    setAddTop(null)
    if (!draft) return
    setComments((cs) => [...cs, draft])
    setPanel("comments")
    setActiveId(draft.id)
    setEditingId(draft.id)
  }

  function saveComment(id: string, text: string) {
    const t = text.trim()
    setComments((cs) =>
      t ? cs.map((c) => (c.id === id ? { ...c, text: t } : c)) : cs.filter((c) => c.id !== id)
    )
    setEditingId(null)
  }

  async function runSuggestion(c: ReviewComment, prompt: string) {
    if (suggest) void discardSuggestion(suggest.id).catch(() => {})
    try {
      const { id } = await startSuggestion({ section: c.section, quote: c.quote, prefix: c.prefix, suffix: c.suffix, text: prompt })
      setSuggest({ id, status: "running", commentId: c.id, version: version!.v, prompt })
    } catch (error) {
      setManuscriptNotice(error instanceof Error ? error.message : String(error))
    }
  }

  function closeSuggestion() {
    if (suggest) void discardSuggestion(suggest.id).catch(() => {})
    setSuggest(null)
  }

  async function acceptSuggestion() {
    if (!suggest) return
    try {
      const result = await applySuggestion(suggest.id, suggest.commentId, suggest.version)
      window.MANUSCRIPT_VERSIONS = result.versions
      setVersions(result.versions)
      setWorking(result.draft)
      setSuggest(null)
      setManuscriptNotice(`Applied as v${result.versions[result.versions.length - 1].v}`)
    } catch (error) {
      setSuggest((s) => s && { ...s, status: "error", error: error instanceof Error ? error.message : String(error) })
    }
  }

  function cancelEdit(id: string) {
    setComments((cs) => cs.filter((c) => c.id !== id || c.text))
    setEditingId(null)
  }

  function focusComment(id: string) {
    setActiveId(id)
    docRef.current!
      .querySelector(`[data-comment="${id}"]`)
      ?.scrollIntoView({ block: "center", behavior: "smooth" })
  }

  // Hovering a citation shows its reference entry, links included, without scrolling to the list.
  function onDocOver(e: React.MouseEvent) {
    const a = (e.target as Element).closest("a.cite")
    const li = a && docRef.current!.querySelector(a.getAttribute("href")!)
    if (!a || !li) return
    clearTimeout(citeTimer.current)
    const r = a.getBoundingClientRect(), p = paperRef.current!.getBoundingClientRect()
    setCitePop({ top: r.bottom - p.top + 6, left: Math.min(r.left - p.left, p.width - 420), html: li.innerHTML })
  }
  function hideCite() {
    citeTimer.current = window.setTimeout(() => setCitePop(null), 250)
  }

  function onDocClick(e: React.MouseEvent) {
    if (editing) {
      e.preventDefault()
      return
    }
    const hit = (e.target as Element).closest("[data-comment]")
    if (!hit || !reviewing) return
    const id = hit.getAttribute("data-comment")!
    setPanel("comments")
    setActiveId(id)
    requestAnimationFrame(() =>
      cardRefs.current.get(id)?.scrollIntoView({ block: "nearest", behavior: "smooth" })
    )
  }

  function onDocDoubleClick(e: React.MouseEvent) {
    if (busyRef.current) return
    if (!editing && !canEdit) return
    const block = (e.target as Element).closest(EDITABLE_BLOCKS)
    if (!block || block.closest("[data-editor-host]") || !docRef.current!.contains(block)) return
    e.preventDefault()
    if (editing) openParagraph(block)
    else {
      pendingParagraphRef.current = Array.from(docRef.current!.querySelectorAll(EDITABLE_BLOCKS)).indexOf(block)
      startEditing()
    }
  }

  function gotoChange(step: number) {
    const els = Array.from(docRef.current!.querySelectorAll("[data-change]"))
    if (!els.length) return
    const k = (changeAt + step + els.length) % els.length
    els.forEach((e, i) => e.classList.toggle("current", i === k))
    els[k].scrollIntoView({ block: "center", behavior: "smooth" })
    setChangeAt(k)
  }

  const togglePanel = (p: Panel) => setPanel((cur) => (cur === p ? null : p))
  // Copies every version's comments as JSON, using the open version's live list instead of the saved file.
  // Copies the open version's comments as JSON. They are already loaded, so the write happens
  // directly in the tap, which phones require.
  function copyComments() {
    const text = JSON.stringify({ [`v${loadedFor}`]: comments }, null, 2)
    const done = (ok: boolean) =>
      setManuscriptNotice(ok ? `Copied ${comments.length} comments as JSON` : "Copy failed: the browser blocked the clipboard")
    const legacy = () => {
      const ta = document.createElement("textarea")
      ta.value = text
      ta.style.cssText = "position:fixed;top:0;opacity:0"
      document.body.appendChild(ta)
      ta.select()
      ta.setSelectionRange(0, text.length)
      const ok = document.execCommand("copy")
      ta.remove()
      return ok
    }
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(() => done(true), () => done(legacy()))
    else done(legacy())
  }

  const vName = (i: number) => i === -1 ? "Working copy" : `v${versions[i].v}`

  // Sections outline: the manuscript's headings, rebuilt whenever the displayed document changes.
  const [outlineOpen, setOutlineOpen] = useState(window.innerWidth >= 640)
  const [outline, setOutline] = useState<{ id: string; num: string; html: string; level: number }[]>([])
  const [activeSection, setActiveSection] = useState("")
  useEffect(() => {
    const doc = docRef.current
    if (!doc) return
    const heads = Array.from(doc.querySelectorAll<HTMLElement>("h1, h2"))
    setOutline(heads.map((h, k) => {
      if (!h.id) h.id = `sec-${k}`
      const c = h.cloneNode(true) as HTMLElement
      const num = c.querySelector(".secno")?.textContent ?? ""
      c.querySelector(".secno")?.remove()
      return { id: h.id, num, html: c.innerHTML, level: h.tagName === "H1" ? 1 : 2 }
    }))
  }, [version, compareWith, editing])
  useEffect(() => {
    const view = paperRef.current?.closest<HTMLElement>("[data-slot=scroll-area-viewport]")
    if (!view) return
    const onScroll = () => {
      const top = view.getBoundingClientRect().top + 120
      let current = outline[0]?.id ?? ""
      for (const o of outline) {
        const el = document.getElementById(o.id)
        if (el && el.getBoundingClientRect().top <= top) current = o.id
      }
      setActiveSection(current)
    }
    onScroll()
    view.addEventListener("scroll", onScroll, { passive: true })
    return () => view.removeEventListener("scroll", onScroll)
  }, [outline])

  // A refresh returns to the last reading position, once the figures have their height.
  const scrollRestored = useRef(false)
  useEffect(() => {
    const view = paperRef.current?.closest<HTMLElement>("[data-slot=scroll-area-viewport]")
    if (!view || !version) return
    if (!scrollRestored.current) {
      scrollRestored.current = true
      const y = Number(localStorage.getItem("m2-scroll") ?? 0)
      const imgs = Array.from(docRef.current?.querySelectorAll("img") ?? [])
      view.scrollTop = y
      Promise.all(imgs.map((i) => i.complete || new Promise((r) => { i.onload = i.onerror = r })))
        .then(() => { view.scrollTop = y })
    }
    const onScroll = () => localStorage.setItem("m2-scroll", String(view.scrollTop))
    view.addEventListener("scroll", onScroll, { passive: true })
    return () => view.removeEventListener("scroll", onScroll)
  }, [version])

  // Notices fade out on their own.
  useEffect(() => {
    if (!manuscriptNotice) return
    const t = setTimeout(() => setManuscriptNotice(""), 5000)
    return () => clearTimeout(t)
  }, [manuscriptNotice])

  // The panel keeps its last content while it slides out.
  const lastPanel = useRef<Panel>("comments")
  if (panel) lastPanel.current = panel
  const shown = panel ?? lastPanel.current
  const pill = selectedWords > 0 || manuscriptNotice !== ""

  return (
    <div className="relative flex h-svh flex-col overflow-hidden text-foreground print:h-auto print:overflow-visible">
      {/* The manuscript stays centred below the fixed top bar. The panel and scrollbar float above it. */}
      <ScrollArea className="min-h-0 flex-1" onMouseUp={onDocMouseUp}>
        <div className="px-3 pt-4 pb-28 sm:px-6 sm:pt-8 print:p-0">
          <div
            ref={paperRef}
            className="relative mx-auto w-full max-w-[210mm] rounded-2xl bg-card px-5 py-8 shadow-[0_1px_2px_oklch(0.3_0.03_60/0.06),0_28px_70px_-32px_oklch(0.3_0.05_60/0.4)] ring-1 ring-border/70 sm:px-[25.4mm] sm:py-[25.4mm] print:w-auto print:max-w-none print:rounded-none print:p-0 print:shadow-none print:ring-0"
          >
            <article
              ref={docRef}
              className="paper"
              onClick={onDocClick}
              onDoubleClick={onDocDoubleClick}
              onMouseOver={onDocOver}
              onMouseOut={(e) => (e.target as Element).closest("a.cite") && hideCite()}
            />
            {citePop && (
              <div
                className="paper absolute z-20 w-[400px] max-w-[calc(100vw-1.5rem)] rounded-xl border bg-popover p-3 text-popover-foreground shadow-lg print:hidden"
                style={{ top: citePop.top, left: citePop.left, fontSize: "9pt" }}
                onMouseEnter={() => clearTimeout(citeTimer.current)}
                onMouseLeave={hideCite}
                dangerouslySetInnerHTML={{ __html: citePop.html }}
              />
            )}
            {addTop !== null && (
              <Hint text="Add comment">
                <Button
                  variant="outline"
                  size="icon"
                  aria-label="Add comment"
                  className="absolute right-4"
                  style={{ top: addTop }}
                  onMouseDown={(e) => e.preventDefault()}
                  onPointerDown={(e) => {
                    // A tap would clear the selection (and this button) before click fires.
                    if (e.pointerType !== "mouse") { e.preventDefault(); addComment() }
                  }}
                  onClick={addComment}
                >
                  <MessageSquarePlusIcon />
                </Button>
              </Hint>
            )}
          </div>
        </div>
      </ScrollArea>

      <header className="relative z-30 order-first flex h-14 shrink-0 items-center gap-3 border-b bg-background px-3 print:hidden">
        <div className="flex min-w-0 items-center gap-3">
          <Hint text="Sections">
            <Toggle aria-label="Sections" pressed={outlineOpen} onPressedChange={setOutlineOpen}>
              <ListTreeIcon />
            </Toggle>
          </Hint>
          <span className="hidden size-9 shrink-0 items-center justify-center rounded-xl bg-primary/12 text-primary sm:flex">
            <FileTextIcon className="size-4" />
          </span>
          <div className="hidden min-w-0 flex-col leading-tight sm:flex">
            <span className="font-title truncate text-[15px]">
              Online NCF stability indicator framework for adaptive control
            </span>
            <span className="truncate text-xs text-muted-foreground">Paper 2 · Methodology draft</span>
          </div>
          {version && (
            <Badge variant={comparing ? "secondary" : "outline"} className="shrink-0">
              {compareWith !== null ? `${vName(compareWith)} → ${vName(selected)}` : vName(selected)}
              {!comparing && selected === last && " · latest saved"}
            </Badge>
          )}
        </div>
        <div className="ml-auto flex items-center gap-1">
          <Hint
            text={
              save === "local"
                ? "Not saving to disk. Open the page with open_review.cmd"
                : save === "saving"
                  ? "Saving…"
                  : `Saved to writing/.agent/comments/v${version?.v}.json`
            }
          >
            <span
              className="flex size-8 items-center justify-center text-muted-foreground"
              aria-label="Save status"
              tabIndex={0}
            >
              {save === "local" ? <CloudOffIcon /> : save === "saving" ? <LoaderIcon /> : <CloudCheckIcon />}
            </span>
          </Hint>
          <Separator orientation="vertical" className="mx-1 h-5" />
          {selected === -1 && disk && (
            <Hint text={busy ? "Saving…" : "Save the working copy as a new version"}>
              <Button variant="ghost" size="icon" aria-label="Save as a new version" disabled={!canEdit} onClick={saveEdits}>
                <SaveIcon />
              </Button>
            </Hint>
          )}
          <Hint text="Comments">
            <Toggle
              aria-label="Comments"
              pressed={panel === "comments"}
              onPressedChange={() => togglePanel("comments")}
            >
              <MessageSquareIcon />
              {comments.length > 0 && <span className="tabular-nums">{comments.length}</span>}
            </Toggle>
          </Hint>
          <Hint text="Version history">
            <Toggle
              aria-label="Version history"
              pressed={panel === "history"}
              onPressedChange={() => togglePanel("history")}
            >
              <HistoryIcon />
            </Toggle>
          </Hint>
          <Hint text={dark ? "Light theme" : "Dark theme"}>
            <Button
              variant="ghost"
              size="icon"
              aria-label="Toggle theme"
              onClick={() => setTheme(dark ? "light" : "dark")}
            >
              {dark ? <SunIcon /> : <MoonIcon />}
            </Button>
          </Hint>
        </div>
      </header>

      {/* Sections float over the left edge, mirroring the right panel, and never move the manuscript. */}
      <nav
        aria-label="Sections"
        aria-hidden={!outlineOpen}
        inert={!outlineOpen}
        className={cn(
          "absolute top-[4.25rem] left-3 z-20 flex max-h-[calc(100%-5.5rem)] w-[calc(100%-1.5rem)] flex-col sm:w-[360px] transition-[opacity,translate] duration-300 ease-out print:hidden",
          outlineOpen ? "translate-x-0 opacity-100" : "pointer-events-none -translate-x-6 opacity-0"
        )}
      >
        <div className="flex min-h-0 flex-col overflow-hidden rounded-2xl border bg-popover/95 shadow-xl backdrop-blur-md">
          <div className="flex h-12 shrink-0 items-center border-b px-4 text-sm font-medium">Sections</div>
          <ScrollArea className="min-h-0">
            <ol className="flex flex-col gap-0.5 p-2">
              {outline.map((o) => (
                <li key={o.id}>
                  <button
                    type="button"
                    onClick={() => document.getElementById(o.id)?.scrollIntoView({ behavior: "smooth", block: "start" })}
                    className={cn(
                      "relative flex w-full items-baseline gap-2 rounded-lg px-2.5 py-1.5 text-left text-[13px] leading-snug text-muted-foreground transition-colors hover:bg-muted hover:text-foreground",
                      o.level === 1 && "font-title text-[14px] text-foreground",
                      activeSection === o.id && "bg-accent text-accent-foreground"
                    )}
                  >
                    {activeSection === o.id && <span className="absolute top-1.5 bottom-1.5 left-0 w-0.5 rounded-full bg-primary" />}
                    {o.num && <span className="w-6 shrink-0 tabular-nums">{o.num}</span>}
                    <span className="min-w-0" dangerouslySetInnerHTML={{ __html: o.html }} />
                  </button>
                </li>
              ))}
            </ol>
          </ScrollArea>
        </div>
      </nav>

      {/* Comments and history slide in over the right edge without moving the manuscript. */}
      <aside
        aria-hidden={!panel}
        inert={!panel}
        className={cn(
          "absolute top-[4.25rem] inset-x-3 bottom-3 z-20 flex flex-col sm:inset-x-auto sm:right-3 sm:w-[360px] transition-[opacity,translate] duration-300 ease-out print:hidden",
          panel ? "translate-x-0 opacity-100" : "pointer-events-none translate-x-6 opacity-0"
        )}
      >
        <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-2xl border bg-popover/95 shadow-xl backdrop-blur-md">
          <div className="flex h-12 shrink-0 items-center gap-2 border-b px-4">
            <span className="text-sm font-medium">
              {shown === "history" ? "Version history" : `Comments on ${vName(selected)}`}
            </span>
            {shown === "comments" && comments.length > 0 && (
              <Badge variant="secondary">{comments.length}</Badge>
            )}
            {shown === "comments" && (
              <Hint text="Copy these comments as JSON">
                <Button variant="ghost" size="icon-sm" className="ml-auto" aria-label="Copy all comments" onClick={copyComments}>
                  <CopyIcon />
                </Button>
              </Hint>
            )}
            <Hint text="Close panel">
              <Button
                variant="ghost"
                size="icon-sm"
                className={shown === "comments" ? undefined : "ml-auto"}
                aria-label="Close panel"
                onClick={() => setPanel(null)}
              >
                <XIcon />
              </Button>
            </Hint>
          </div>

          {shown === "history" && compareWith !== null && (
            <div className="flex shrink-0 items-center gap-2 border-b px-4 py-2 text-sm">
              <span className="text-muted-foreground">Changes from</span>
              <Badge className="border-sky-500 bg-sky-500 text-white">{vName(compareWith)}</Badge>
              <span className="text-muted-foreground">→</span>
              <Badge>{vName(selected)}</Badge>
              <Button variant="outline" size="xs" className="ml-auto" disabled={dirty || busy}
                onClick={() => { cancelParagraph(); setEditing(false); setSelected(compareWith); setCompareWith(selected) }}>
                Swap
              </Button>
              <Hint text="Stop comparing">
                <Button variant="ghost" size="icon-sm" aria-label="Stop comparing" onClick={() => setCompareWith(null)}>
                  <XIcon />
                </Button>
              </Hint>
            </div>
          )}
          {shown === "history" && comparing && (
            <div className="flex shrink-0 items-center gap-2 border-b px-4 py-2 text-sm">
              <span className="text-[var(--ins)] tabular-nums">+{stats.added}</span>
              <span className="text-[var(--del)] tabular-nums">−{stats.deleted}</span>
              <span className="text-muted-foreground">words</span>
              <span className="ml-auto text-xs text-muted-foreground tabular-nums">
                {changeAt < 0 ? stats.changes : `${changeAt + 1} / ${stats.changes}`} changes
              </span>
              <Hint text="Previous change">
                <Button variant="outline" size="icon-sm" aria-label="Previous change" disabled={!stats.changes} onClick={() => gotoChange(-1)}>
                  <ChevronUpIcon />
                </Button>
              </Hint>
              <Hint text="Next change">
                <Button variant="outline" size="icon-sm" aria-label="Next change" disabled={!stats.changes} onClick={() => gotoChange(1)}>
                  <ChevronDownIcon />
                </Button>
              </Hint>
            </div>
          )}

          <ScrollArea className="min-h-0 flex-1">
            {shown === "history" ? (
              <ItemGroup className="gap-0.5 p-2">
                <p className="px-2 pb-1 text-xs text-muted-foreground">
                  Tap a version to make it active. Tap Compare on another to see its changes.
                </p>
                {dirty && <p className="px-2 py-1 text-xs text-muted-foreground">Update or cancel the open paragraph to browse versions.</p>}
                {[-1, ...versions.map((_, i) => i).reverse()].map((i) => (
                  <VersionRow
                    key={i}
                    name={vName(i)}
                    date={i === -1 ? "now" : versions[i].date.slice(5)}
                    note={i === -1 ? "Working copy" : versions[i].note}
                    words={i === -1 ? wordCount(htmlOf(-1)) : counts[i]}
                    role={i === selected ? "active" : i === compareWith ? "compared" : null}
                    locked={dirty || busy}
                    canRestore={disk === true && working !== null && !dirty && !busy}
                    onRestore={i === -1 ? undefined : () => void persist("restore", versions[i].v)}
                    canDelete={versions.length > 1 && !dirty && !busy}
                    onDelete={i === -1 ? undefined : () => setDeleting(i)}
                    onSelect={() => {
                      cancelParagraph()
                      setEditing(false)
                      setSelected(i)
                      if (compareWith === i) setCompareWith(null)
                    }}
                    onCompare={() => { cancelParagraph(); setEditing(false); setCompareWith(compareWith === i ? null : i) }}
                  />
                ))}
              </ItemGroup>
            ) : sorted.length === 0 ? (
              <Empty className="py-16">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <MessageSquarePlusIcon />
                  </EmptyMedia>
                  <EmptyTitle>No comments on {vName(selected)}</EmptyTitle>
                  <EmptyDescription>
                    Select text in the manuscript, then use the comment button in the margin.
                  </EmptyDescription>
                </EmptyHeader>
              </Empty>
            ) : (
              <div className="flex flex-col gap-2 p-3">
                {sorted.map((c, i) => (
                  <CommentCard
                    key={c.id}
                    n={i + 1}
                    comment={c}
                    active={c.id === activeId}
                    editing={c.id === editingId}
                    cardRef={(el) =>
                      el ? cardRefs.current.set(c.id, el) : cardRefs.current.delete(c.id)
                    }
                    onFocus={() => focusComment(c.id)}
                    onEdit={() => setEditingId(c.id)}
                    onSave={(t) => saveComment(c.id, t)}
                    onCancel={() => cancelEdit(c.id)}
                    onDelete={() => saveComment(c.id, "")}
                    suggestion={suggest?.commentId === c.id ? suggest : null}
                    canSuggest={disk === true && selected === -1 && !comparing && !editing}
                    onSuggest={(prompt) => runSuggestion(c, prompt)}
                    onApply={acceptSuggestion}
                    onDiscard={closeSuggestion}
                  />
                ))}
              </div>
            )}
          </ScrollArea>
        </div>
      </aside>

      {/* Transient status: fades in for a selection count or a notice, never shifts the page. */}
      <div
        role="status"
        aria-live="polite"
        className={cn(
          "pointer-events-none absolute bottom-5 left-1/2 z-50 -translate-x-1/2 transition-[opacity,translate] duration-300 print:hidden",
          pill ? "translate-y-0 opacity-100" : "translate-y-2 opacity-0"
        )}
      >
        <div className="flex items-center gap-3 rounded-full border bg-popover/90 px-4 py-1.5 text-xs text-muted-foreground shadow-md backdrop-blur-md tabular-nums">
          {selectedWords > 0 && <span>{selectedWords.toLocaleString()} words selected</span>}
          {selectedWords > 0 && manuscriptNotice && <span className="h-3 w-px bg-border" />}
          {manuscriptNotice && <span className="text-foreground">{manuscriptNotice}</span>}
        </div>
      </div>

      {editTarget && createPortal(
        <div className="flex flex-col gap-2 rounded-xl border bg-background p-2 font-sans text-sm leading-normal">
          <iframe
            ref={frameRef}
            title="Paragraph editor"
            srcDoc={editTarget.source}
            className="block w-full border-0"
            style={{ height: editTarget.height }}
            onLoad={prepareParagraph}
          />
          {editorNotice && <div role="status">{editorNotice}</div>}
          <div className="flex justify-end gap-2 border-t pt-2">
            <Hint text="Cancel (discard this paragraph's changes)">
              <Button variant="ghost" size="icon-sm" aria-label="Cancel" onClick={closeParagraph} disabled={busy}>
                <XIcon />
              </Button>
            </Hint>
            <Hint text={busy ? "Saving…" : "Update paragraph"}>
              <Button size="icon-sm" aria-label="Update paragraph" onClick={updateParagraph} disabled={!draftDirty || busy}>
                {busy ? <LoaderIcon /> : <CheckIcon />}
              </Button>
            </Hint>
          </div>
        </div>, editTarget.host
      )}

      <AlertDialog open={deleting !== null} onOpenChange={(open) => open || setDeleting(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete {deleting !== null && vName(deleting)}?</AlertDialogTitle>
            <AlertDialogDescription>
              The version and its comments are removed permanently. The working copy is not affected.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep it</AlertDialogCancel>
            <AlertDialogAction variant="destructive" onClick={() => deleting !== null && void removeVersion(deleting)}>
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {eqHosts.map(({ host, id }) =>
        createPortal(<EquationCopy text={word[id]} number={id.replace("eq", "")} />, host, id)
      )}
    </div>
  )
}

function VersionRow(props: {
  name: string
  date: string
  note: string
  words: number
  role: "active" | "compared" | null
  locked: boolean
  canRestore: boolean
  onRestore?: () => void
  canDelete: boolean
  onDelete?: () => void
  onSelect: () => void
  onCompare: () => void
}) {
  const { name, date, note, words, role, locked } = props
  return (
    <Item
      size="xs"
      className={cn(
        "group/version cursor-pointer border-l-4 border-transparent hover:bg-muted/50",
        role === "active" && "border-l-primary bg-primary/12 hover:bg-primary/15",
        role === "compared" && "border-l-sky-500 bg-sky-500/10 hover:bg-sky-500/15",
        locked && "pointer-events-none opacity-50"
      )}
      render={
        <div
          role="button"
          tabIndex={0}
          aria-disabled={locked}
          aria-current={role === "active" || undefined}
          title={[date, note].filter(Boolean).join(" · ")}
          onClick={() => { if (!locked && role !== "active") props.onSelect() }}
          onKeyDown={(e) => { if (e.key === "Enter" && e.target === e.currentTarget && !locked) props.onSelect() }}
        />
      }
    >
      <ItemContent className="min-w-0 text-sm whitespace-nowrap">
        <div className="flex items-baseline">
          <span className="mr-2 font-medium tabular-nums">{name}</span>
          <span className="text-xs text-muted-foreground tabular-nums">{date}</span>
          <span className="ml-auto pl-2 text-xs text-muted-foreground tabular-nums">{words.toLocaleString()} w</span>
        </div>
      </ItemContent>
      <ItemActions className="justify-center">
        {props.onRestore && (
          <Hint text={`Revert the working copy to ${name}`}>
            <Button variant="ghost" size="icon-sm" aria-label={`Revert to ${name}`} disabled={!props.canRestore}
              className="opacity-0 group-hover/version:opacity-100 focus-visible:opacity-100"
              onClick={(e) => { e.stopPropagation(); props.onRestore!() }}>
              <RotateCcwIcon />
            </Button>
          </Hint>
        )}
        {props.onDelete && (
          <Hint text={`Delete ${name}`}>
            <Button variant="ghost" size="icon-sm" aria-label={`Delete ${name}`} disabled={!props.canDelete}
              className="opacity-0 group-hover/version:opacity-100 focus-visible:opacity-100"
              onClick={(e) => { e.stopPropagation(); props.onDelete!() }}>
              <Trash2Icon />
            </Button>
          </Hint>
        )}
        {role === "active" ? (
          <Badge className="w-20 justify-center">Active</Badge>
        ) : (
          <Button
            variant={role === "compared" ? "default" : "outline"}
            size="xs"
            disabled={locked}
            aria-pressed={role === "compared"}
            className={cn("w-20", role === "compared" && "bg-sky-500 text-white hover:bg-sky-600")}
            onClick={(e) => { e.stopPropagation(); props.onCompare() }}
          >
            {role === "compared" ? "Compared" : "Compare"}
          </Button>
        )}
      </ItemActions>
    </Item>
  )
}

function EquationCopy({ text, number }: { text?: string; number: string }) {
  const [done, setDone] = useState(false)
  if (!text) return null
  return (
    <Hint text={done ? "Copied" : "Copy for Word (Alt+=, paste, Professional)"}>
      <Button
        variant="ghost"
        size="icon-sm"
        aria-label={`Copy equation ${number} for Word`}
        onClick={async () => {
          await navigator.clipboard.writeText(text)
          setDone(true)
          setTimeout(() => setDone(false), 1400)
        }}
      >
        {done ? <CheckIcon /> : <CopyIcon />}
      </Button>
    </Hint>
  )
}

function CommentCard(props: {
  n: number
  comment: ReviewComment
  active: boolean
  editing: boolean
  cardRef: (el: HTMLElement | null) => void
  onFocus: () => void
  onEdit: () => void
  onSave: (text: string) => void
  onCancel: () => void
  onDelete: () => void
  suggestion: (Suggestion & { prompt: string }) | null
  canSuggest: boolean
  onSuggest: (prompt: string) => void
  onApply: () => void
  onDiscard: () => void
}) {
  const { n, comment: c, active, editing, suggestion: s } = props
  const [draft, setDraft] = useState(c.text)
  useEffect(() => setDraft(c.text), [c.text, editing])
  const [prompt, setPrompt] = useState(c.text)
  useEffect(() => setPrompt(s?.prompt ?? c.text), [s?.prompt, c.text])
  return (
    <div
      ref={props.cardRef}
      className={cn(
        "flex flex-col gap-2 rounded-xl border p-3 text-sm transition-colors",
        active ? "border-ring bg-muted/50" : "hover:bg-muted/30"
      )}
      onClick={props.onFocus}
    >
      <div className="flex items-center gap-2 text-xs text-muted-foreground">
        <span className="font-medium text-foreground tabular-nums">#{n}</span>
        <span className="truncate">{c.section}</span>
        {!editing && (
          <div className="ml-auto flex gap-0.5">
            {props.canSuggest && !s && (
              <Hint text="Apply with the agent">
                <Button
                  variant="ghost"
                  size="icon-xs"
                  aria-label="Apply comment with the agent"
                  onClick={(e) => {
                    e.stopPropagation()
                    props.onSuggest(c.text)
                  }}
                >
                  <SparklesIcon />
                </Button>
              </Hint>
            )}
            <Hint text="Edit">
              <Button
                variant="ghost"
                size="icon-xs"
                aria-label="Edit comment"
                onClick={(e) => {
                  e.stopPropagation()
                  props.onEdit()
                }}
              >
                <PencilIcon />
              </Button>
            </Hint>
            <Hint text="Delete">
              <Button
                variant="ghost"
                size="icon-xs"
                aria-label="Delete comment"
                onClick={(e) => {
                  e.stopPropagation()
                  props.onDelete()
                }}
              >
                <Trash2Icon />
              </Button>
            </Hint>
          </div>
        )}
      </div>
      <blockquote className="line-clamp-3 border-l-2 pl-2 text-muted-foreground">{c.quote}</blockquote>
      {editing ? (
        <div className="flex flex-col gap-2">
          <Textarea
            autoFocus
            value={draft}
            placeholder="Write a comment"
            onChange={(e) => setDraft(e.target.value)}
            onBlur={() => props.onSave(draft)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) props.onSave(draft)
              if (e.key === "Escape") props.onCancel()
            }}
          />
          <div className="flex justify-end gap-1">
            <Hint text="Cancel (Esc)">
              <Button
                variant="ghost"
                size="icon-sm"
                aria-label="Cancel"
                onMouseDown={(e) => e.preventDefault()}
                onClick={props.onCancel}
              >
                <XIcon />
              </Button>
            </Hint>
            <Hint text="Save (Ctrl+Enter)">
              <Button
                size="icon-sm"
                aria-label="Save comment"
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => props.onSave(draft)}
              >
                <CheckIcon />
              </Button>
            </Hint>
          </div>
        </div>
      ) : (
        <p className="whitespace-pre-wrap">{c.text}</p>
      )}
      {s && (
        <div className="flex flex-col gap-2 border-t pt-2" onClick={(e) => e.stopPropagation()}>
          {s.status === "running" && (
            <p className="flex items-center gap-2 text-muted-foreground">
              <LoaderIcon className="size-4 animate-spin" /> The agent is revising the passage…
              <Button variant="ghost" size="xs" className="ml-auto" onClick={props.onDiscard}>Cancel</Button>
            </p>
          )}
          {s.status === "error" && <p className="text-destructive">{s.error}</p>}
          {s.status === "done" && (
            <p className="text-muted-foreground">{s.summary || "The changes are shown in the manuscript."}</p>
          )}
          {s.status !== "running" && (
            <>
              <Textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} aria-label="Prompt for the agent" />
              <div className="flex justify-end gap-1">
                <Button variant="ghost" size="sm" onClick={props.onDiscard}>
                  <XIcon /> Cancel
                </Button>
                <Button variant="outline" size="sm" onClick={() => props.onSuggest(prompt)}>
                  <RefreshCwIcon /> Regenerate
                </Button>
                {s.status === "done" && (
                  <Button size="sm" onClick={props.onApply}>
                    <CheckIcon /> Apply
                  </Button>
                )}
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}

export default App
