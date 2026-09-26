// Word-level comparison of two article versions, rendered like Word's track changes.
// Changed paragraphs get inline <ins>/<del>; added or removed blocks are marked whole.

type Op = { t: "=" | "-" | "+"; i: number; j: number }
type Token = { k: string; h: string }

const TEXT = new Set(["P", "H1", "H2", "H3", "LI"])
const ATOMIC = new Set(["MATH", "A", "SVG"])

function blocks(html: string): Element[] {
  const t = document.createElement("template")
  t.innerHTML = html
  const out: Element[] = []
  const walk = (el: Element | DocumentFragment) => {
    for (const c of Array.from(el.children))
      ["OL", "UL", "SECTION"].includes(c.tagName) ? walk(c) : out.push(c)
  }
  walk(t.content)
  return out
}

const esc = (x: string) =>
  x.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]!)

function tokens(el: Element): Token[] {
  const out: Token[] = []
  const rec = (node: Node) => {
    for (const n of Array.from(node.childNodes)) {
      if (n.nodeType === Node.TEXT_NODE) {
        for (const m of (n as Text).data.matchAll(/\s*\S+\s*|\s+/g))
          out.push({ k: m[0].trim() || " ", h: esc(m[0]) })
      } else if (n instanceof Element) {
        if (ATOMIC.has(n.tagName.toUpperCase()) || n.classList.contains("secno"))
          out.push({ k: n.outerHTML, h: n.outerHTML })
        else rec(n)
      }
    }
  }
  rec(el)
  return out
}

export function lcs(a: string[], b: string[]): Op[] {
  const n = a.length
  const m = b.length
  const L = Array.from({ length: n + 1 }, () => new Uint32Array(m + 1))
  for (let i = n - 1; i >= 0; i--)
    for (let j = m - 1; j >= 0; j--)
      L[i][j] = a[i] === b[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1])
  const ops: Op[] = []
  let i = 0
  let j = 0
  while (i < n && j < m) {
    if (a[i] === b[j]) ops.push({ t: "=", i: i++, j: j++ })
    else if (L[i + 1][j] >= L[i][j + 1]) ops.push({ t: "-", i: i++, j })
    else ops.push({ t: "+", i, j: j++ })
  }
  while (i < n) ops.push({ t: "-", i: i++, j })
  while (j < m) ops.push({ t: "+", i, j: j++ })
  return ops
}

const words = (el: Element) => new Set(el.textContent!.toLowerCase().match(/\w+/g) ?? [])
function similarity(x: Element, y: Element) {
  const a = words(x)
  const b = words(y)
  let k = 0
  a.forEach((w) => b.has(w) && k++)
  return k / Math.max(a.size, b.size, 1)
}

function whole(el: Element, kind: "ins" | "del") {
  const e = el.cloneNode(true) as Element
  e.classList.add(`tr-${kind}-block`)
  e.setAttribute("data-change", kind)
  return e
}

function modified(x: Element, y: Element) {
  const a = tokens(x)
  const b = tokens(y)
  const e = y.cloneNode(false) as Element
  e.innerHTML = lcs(a.map((t) => t.k), b.map((t) => t.k))
    .map((o) =>
      o.t === "=" ? b[o.j].h : o.t === "-" ? `<del>${a[o.i].h}</del>` : `<ins>${b[o.j].h}</ins>`
    )
    .join("")
  if (e.querySelector("ins, del")) e.setAttribute("data-change", "mod")
  return e
}

export type Comparison = { nodes: Element[]; added: number; deleted: number; changes: number }

// Apply authorship color only on Update/Save, preserving the edited DOM and math.
export function markUserInsertions(base: Element, target: Element) {
  const textNodes = (root: Element) => {
    const nodes: Text[] = []
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: (node) => node.parentElement?.closest("math, svg")
        ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT,
    })
    for (let node = walker.nextNode(); node; node = walker.nextNode()) nodes.push(node as Text)
    return nodes
  }
  const nodes = textNodes(target)
  const a = textNodes(base).map(n => n.data).join("").match(/\s+|\S+/g) ?? []
  const b = nodes.map(n => n.data).join("").match(/\s+|\S+/g) ?? []
  const added = new Set(lcs(a, b).filter(op => op.t === "+").map(op => op.j))
  const ranges: { start: number; end: number }[] = []
  let offset = 0
  b.forEach((token, index) => {
    const end = offset + token.length
    if (added.has(index)) {
      const last = ranges.at(-1)
      if (last?.end === offset) last.end = end
      else ranges.push({ start: offset, end })
    }
    offset = end
  })
  offset = 0
  for (const node of nodes) {
    const start = offset
    offset += node.length
    if (node.parentElement?.closest("[data-user-edit]")) continue
    for (const range of ranges.slice().reverse()) {
      const from = Math.max(range.start - start, 0)
      const to = Math.min(range.end - start, node.length)
      if (from >= to) continue
      if (to < node.length) node.splitText(to)
      const text = from ? node.splitText(from) : node
      const mark = document.createElement("span")
      mark.setAttribute("data-user-edit", "")
      text.replaceWith(mark)
      mark.append(text)
    }
  }
}

export function compare(baseHtml: string, targetHtml: string): Comparison {
  const A = blocks(baseHtml)
  const B = blocks(targetHtml)
  const key = (e: Element) => e.outerHTML.replace(/\s+/g, " ")
  const out: Element[] = []
  let dels: Element[] = []
  let adds: Element[] = []
  const flush = () => {
    const used = new Set<number>()
    const pair = new Map<Element, Element>()
    for (const y of adds) {
      let best = -1
      let score = TEXT.has(y.tagName) ? 0.3 : 0.5
      dels.forEach((x, k) => {
        if (used.has(k) || x.tagName !== y.tagName) return
        const q = similarity(x, y)
        if (q > score) [score, best] = [q, k]
      })
      if (best >= 0) {
        used.add(best)
        pair.set(y, dels[best])
      }
    }
    dels.forEach((x, k) => used.has(k) || out.push(whole(x, "del")))
    for (const y of adds) {
      const x = pair.get(y)
      if (!x) out.push(whole(y, "ins"))
      else if (TEXT.has(y.tagName)) out.push(modified(x, y))
      else out.push(whole(x, "del"), whole(y, "ins"))
    }
    dels = []
    adds = []
  }
  for (const o of lcs(A.map(key), B.map(key))) {
    if (o.t === "=") {
      flush()
      out.push(B[o.j].cloneNode(true) as Element)
    } else if (o.t === "-") dels.push(A[o.i])
    else adds.push(B[o.j])
  }
  flush()

  const count = (sel: string) =>
    out.reduce(
      (s, e) =>
        s +
        (e.matches(sel) ? [e] : Array.from(e.querySelectorAll(sel))).reduce(
          (n, x) => n + (x.textContent!.match(/\S+/g)?.length ?? 0),
          0
        ),
      0
    )
  return {
    nodes: out,
    added: count("ins, .tr-ins-block"),
    deleted: count("del, .tr-del-block"),
    changes: out.filter((e) => e.hasAttribute("data-change")).length,
  }
}
