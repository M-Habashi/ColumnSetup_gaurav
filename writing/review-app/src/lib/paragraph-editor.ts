// A separate, fixed-size document keeps typing out of the manuscript's layout tree.
// This document contains no scripts, framework, document-wide styles, or live preview.
import { acceptedHtml } from "./track"
import { lcs, markUserInsertions } from "./diff"

export const EDITABLE_BLOCKS = "p, h1, h2, h3, li, figcaption, td, th"

export function paragraphDocument(html: string) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    html, body { margin: 0; min-height: 100%; }
    body { padding: 0; box-sizing: border-box; font: 17px/1.6 Cambria, Georgia, serif;
      color: inherit; background: transparent; overflow-wrap: break-word; }
    #editor { min-height: 100vh; outline: none; }
    p, h1, h2, h3, li, figcaption, td, th { margin: 0 0 12px; text-align: left; hyphens: none; }
    h1, h2, h3 { font-size: 1.15em; }
    math { font-family: "Cambria Math", math; }
    a { color: inherit; }
    /* only the user's own words are green: earlier updates and what is typed now */
    [data-user-edit], ::highlight(user-ins) { color: var(--user-ins, #1f8a45); }
  </style></head><body><div id="editor" contenteditable="true" role="textbox"
    aria-label="Selected manuscript text" aria-multiline="true" spellcheck="false"
    autocorrect="off" writingsuggestions="false" data-gramm="false">${html}</div></body></html>`
}

function textNodes(root: Element) {
  const nodes: Text[] = []
  const walker = root.ownerDocument.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode: (n) =>
      n.parentElement?.closest("math, svg") ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT,
  })
  for (let n = walker.nextNode(); n; n = walker.nextNode()) nodes.push(n as Text)
  return nodes
}

const split = (nodes: Text[]) => nodes.map((n) => n.data).join("").match(/\s+|\S+/g) ?? []

export const baseWords = (root: Element) => split(textNodes(root))

// Ranges covering the words typed since the paragraph was opened. They drive a
// CSS highlight, so nothing in the editable DOM changes and the caret is untouched.
export function insertedRanges(root: Element, base: string[]): Range[] {
  const nodes = textNodes(root)
  const words = split(nodes)
  const added = new Set(lcs(base, words).filter((o) => o.t === "+").map((o) => o.j))
  const at = (g: number): [Text, number] => {
    let acc = 0
    for (const n of nodes) {
      if (g <= acc + n.length) return [n, g - acc]
      acc += n.length
    }
    return [nodes.at(-1)!, nodes.at(-1)!.length]
  }
  const ranges: Range[] = []
  let offset = 0
  let run: [number, number] | null = null
  const flush = () => {
    if (!run) return
    const r = root.ownerDocument.createRange()
    r.setStart(...at(run[0]))
    r.setEnd(...at(run[1]))
    ranges.push(r)
    run = null
  }
  words.forEach((w, i) => {
    const end = offset + w.length
    if (added.has(i)) run = run ? [run[0], end] : [offset, end]
    else flush()
    offset = end
  })
  flush()
  return ranges
}

// Keep the original heading/list/cell wrapper. Native Enter creates visual lines
// in the small editor; store those as breaks inside that same manuscript block.
export function updatedParagraph(target: Element, editor: Element) {
  const replacement = target.cloneNode(false) as Element
  const template = document.createElement("template")
  template.innerHTML = acceptedHtml(editor)
  template.content.querySelectorAll("div").forEach((line) => {
    if (line.previousSibling) line.before(document.createElement("br"))
    line.replaceWith(...Array.from(line.childNodes))
  })
  replacement.append(template.content)
  markUserInsertions(target, replacement)
  return replacement
}
