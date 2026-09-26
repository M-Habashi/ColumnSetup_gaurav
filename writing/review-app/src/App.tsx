import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import { createPortal } from "react-dom"
import {
  CheckIcon,
  ChevronDownIcon,
  ChevronUpIcon,
  CloudCheckIcon,
  CloudOffIcon,
  CopyIcon,
  EyeIcon,
  FileTextIcon,
  GitCompareArrowsIcon,
  HistoryIcon,
  LoaderIcon,
  MessageSquareIcon,
  MessageSquarePlusIcon,
  MoonIcon,
  PencilIcon,
  RotateCcwIcon,
  SaveIcon,
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
import { deleteVersion, fetchVersions, hasDisk, loadComments, saveComments, loadDraft, writeManuscript, type WorkingDraft } from "@/lib/store"
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
  const [panel, setPanel] = useState<Panel>("comments")
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
    if (compareWith !== null) {
      const r = compare(versions[compareWith].html, version.html)
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
    if (reviewing) setOrder(paintComments(doc, commentsRef.current).order)
  }, [version, versions, compareWith, reviewing, reviewAnchors, editing])

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
    }
    document.addEventListener("selectionchange", onSelection)
    return () => document.removeEventListener("selectionchange", onSelection)
  }, [editing])

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
  const vName = (i: number) => i === -1 ? "Working copy" : `v${versions[i].v}`

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
        <div className="px-6 pt-8 pb-28 print:p-0">
          <div
            ref={paperRef}
            className="relative mx-auto w-[210mm] rounded-2xl bg-card px-[25.4mm] py-[25.4mm] shadow-[0_1px_2px_oklch(0.3_0.03_60/0.06),0_28px_70px_-32px_oklch(0.3_0.05_60/0.4)] ring-1 ring-border/70 print:w-auto print:rounded-none print:p-0 print:shadow-none print:ring-0"
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
                className="paper absolute z-20 w-[400px] rounded-xl border bg-popover p-3 text-popover-foreground shadow-lg print:hidden"
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
          <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary/12 text-primary">
            <FileTextIcon className="size-4" />
          </span>
          <div className="flex min-w-0 flex-col leading-tight">
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
                  : `Saved to writing/comments/v${version?.v}.json`
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

      {/* Comments and history slide in over the right edge without moving the manuscript. */}
      <aside
        aria-hidden={!panel}
        inert={!panel}
        className={cn(
          "absolute top-[4.25rem] right-3 bottom-3 z-20 flex w-[360px] flex-col transition-[opacity,translate] duration-300 ease-out print:hidden",
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
            <Hint text="Close panel">
              <Button
                variant="ghost"
                size="icon-sm"
                className="ml-auto"
                aria-label="Close panel"
                onClick={() => setPanel(null)}
              >
                <XIcon />
              </Button>
            </Hint>
          </div>

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
                <Button variant={selected === -1 ? "secondary" : "ghost"} disabled={dirty || busy}
                  onClick={() => { cancelParagraph(); setEditing(false); setSelected(-1); setCompareWith(null) }}>Working copy</Button>
                {dirty && <p className="px-2 py-1 text-xs text-muted-foreground">Update or cancel the open paragraph to browse versions.</p>}
                {versions
                  .map((_, i) => i)
                  .reverse()
                  .map((i) => (
                    <VersionRow
                      key={i}
                      name={vName(i)}
                      date={versions[i].date}
                      note={versions[i].note}
                      words={counts[i]}
                      selected={i === selected}
                      comparing={i === compareWith}
                      locked={dirty || busy}
                      canRestore={disk === true && working !== null && !dirty && !busy}
                      onRestore={() => void persist("restore", versions[i].v)}
                      canDelete={versions.length > 1 && !dirty && !busy}
                      onDelete={() => setDeleting(i)}
                      onSelect={() => {
                        cancelParagraph()
                        setEditing(false)
                        setSelected(i)
                        setCompareWith(null)
                      }}
                      onCompare={(on) => { cancelParagraph(); setEditing(false); setCompareWith(on ? i : null) }}
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
          "pointer-events-none absolute bottom-5 left-1/2 z-30 -translate-x-1/2 transition-[opacity,translate] duration-300 print:hidden",
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
  selected: boolean
  comparing: boolean
  locked: boolean
  canRestore: boolean
  onRestore: () => void
  canDelete: boolean
  onDelete: () => void
  onSelect: () => void
  onCompare: (on: boolean) => void
}) {
  const { name, date, note, words, selected, comparing, locked } = props
  return (
    <Item
      size="xs"
      variant={selected ? "muted" : "default"}
      className={cn("group/version cursor-pointer hover:bg-muted/50", locked && "pointer-events-none opacity-50")}
      render={
        <div
          role="button"
          tabIndex={0}
          aria-disabled={locked}
          title={[date, note].filter(Boolean).join(" · ")}
          onClick={() => { if (!locked) props.onSelect() }}
          onKeyDown={(e) => { if (e.key === "Enter" && e.target === e.currentTarget && !locked) props.onSelect() }}
        />
      }
    >
      <ItemContent className="flex-row items-center gap-3 text-sm whitespace-nowrap">
        <span className="w-9 font-medium tabular-nums">{name}</span>
        <span className="text-muted-foreground tabular-nums">{date.slice(5)}</span>
        <span className="ml-auto text-muted-foreground tabular-nums">
          {words.toLocaleString()} words
        </span>
      </ItemContent>
      <ItemActions className="justify-center">
        <Hint text={`Revert the working copy to ${name}`}>
          <Button variant="ghost" size="icon-sm" aria-label={`Revert to ${name}`} disabled={!props.canRestore}
            className="opacity-0 group-hover/version:opacity-100 focus-visible:opacity-100"
            onClick={(e) => { e.stopPropagation(); props.onRestore() }}>
            <RotateCcwIcon />
          </Button>
        </Hint>
        <Hint text={`Delete ${name}`}>
          <Button variant="ghost" size="icon-sm" aria-label={`Delete ${name}`} disabled={!props.canDelete}
            className="opacity-0 group-hover/version:opacity-100 focus-visible:opacity-100"
            onClick={(e) => { e.stopPropagation(); props.onDelete() }}>
            <Trash2Icon />
          </Button>
        </Hint>
        {selected ? (
          <Hint text="Viewing this version">
            <span className="flex text-muted-foreground" aria-label="Viewing this version" tabIndex={0}>
              <EyeIcon className="size-4" />
            </span>
          </Hint>
        ) : (
          <Hint text={comparing ? "Stop comparing" : `Compare with ${name}`}>
            <Toggle
              size="sm"
              disabled={locked}
              aria-label={`Compare with ${name}`}
              pressed={comparing}
              onPressedChange={props.onCompare}
              onClick={(e) => e.stopPropagation()}
              className={cn(
                !comparing && "opacity-0 group-hover/version:opacity-100 focus-visible:opacity-100"
              )}
            >
              <GitCompareArrowsIcon />
            </Toggle>
          </Hint>
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
}) {
  const { n, comment: c, active, editing } = props
  const [draft, setDraft] = useState(c.text)
  useEffect(() => setDraft(c.text), [c.text, editing])
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
    </div>
  )
}

export default App
