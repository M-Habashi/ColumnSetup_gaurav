// Text-quote anchoring for review comments: a comment stores its quote plus
// surrounding context, so it can be found again after the page is rebuilt.

export type ReviewComment = {
  id: string
  section: string
  quote: string
  prefix: string
  suffix: string
  text: string
  created: string
}

type Indexed = { n: Text; s: number }

const SKIP = ".eq-copy, title, desc"

export function textIndex(root: Element) {
  const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode: (n) =>
      n.parentElement?.closest(SKIP) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT,
  })
  const list: Indexed[] = []
  let pos = 0
  for (let n = w.nextNode() as Text | null; n; n = w.nextNode() as Text | null) {
    list.push({ n, s: pos })
    pos += n.data.length
  }
  return { list, text: list.map((x) => x.n.data).join("") }
}

function offsetOf(list: Indexed[], container: Node, offset: number) {
  if (container.nodeType === Node.TEXT_NODE) {
    const x = list.find((x) => x.n === container)
    if (x) return x.s + offset
  }
  const probe = document.createRange()
  probe.setStart(container, offset)
  const x = list.find((x) => probe.comparePoint(x.n, 0) >= 0)
  return x ? x.s : list.reduce((a, x) => a + x.n.data.length, 0)
}

function sectionOf(root: Element, node: Node) {
  let h = "Opening"
  root.querySelectorAll("h2").forEach((e) => {
    if (e.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)
      h = e.textContent ?? h
  })
  return h
}

export function draftFromRange(root: Element, r: Range): ReviewComment | null {
  const { list, text } = textIndex(root)
  const start = offsetOf(list, r.startContainer, r.startOffset)
  const end = offsetOf(list, r.endContainer, r.endOffset)
  if (end <= start) return null
  return {
    id: "c" + Date.now(),
    section: sectionOf(root, r.startContainer),
    quote: text.slice(start, end),
    prefix: text.slice(Math.max(0, start - 40), start),
    suffix: text.slice(end, end + 40),
    text: "",
    created: new Date().toISOString(),
  }
}

// Wraps each comment's text in <mark data-comment>; equations and figures,
// which cannot hold a <mark>, are outlined instead. Returns ids that no longer match.
export function paintComments(root: Element, comments: ReviewComment[]) {
  const orphans = new Set<string>()
  const located = comments
    .map((c) => {
      const { text } = textIndex(root)
      let i = text.indexOf(c.prefix + c.quote + c.suffix)
      i = i >= 0 ? i + c.prefix.length : text.indexOf(c.quote)
      if (i < 0 || !c.quote) orphans.add(c.id)
      return { c, start: i, end: i + c.quote.length }
    })
    .filter((x) => x.start >= 0)
  for (const { c, start, end } of located) {
    const { list } = textIndex(root)
    for (const { n, s } of list) {
      const a = Math.max(start - s, 0)
      const b = Math.min(end - s, n.data.length)
      if (a >= b) continue
      const box = n.parentElement?.closest("svg")
        ? n.parentElement.closest("figure")
        : n.parentElement?.closest("math")
      if (box) {
        box.classList.add("cmt-box")
        box.setAttribute("data-comment", c.id)
        continue
      }
      let t = n
      if (a > 0) t = t.splitText(a)
      if (b - a < t.data.length) t.splitText(b - a)
      const m = document.createElement("mark")
      m.className = "cmt"
      m.dataset.comment = c.id
      t.replaceWith(m)
      m.append(t)
    }
  }
  return { orphans, order: located.sort((x, y) => x.start - y.start).map((x) => x.c.id) }
}
