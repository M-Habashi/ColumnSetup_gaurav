// Native editing helpers. Document serialization runs only when entering or finishing editing.

const LOCKED = "math, svg, .equation"

export function lockBlocks(root: Element) {
  root.querySelectorAll(LOCKED).forEach((el) => el.setAttribute("contenteditable", "false"))
}

// The manuscript as it reads after accepting the edits.
export function acceptedHtml(root: Element) {
  const c = root.cloneNode(true) as Element
  c.querySelectorAll("del, .eq-copy").forEach((e) => e.remove())
  c.querySelectorAll("ins").forEach((i) => i.replaceWith(...Array.from(i.childNodes)))
  c.querySelectorAll("[contenteditable]").forEach((e) => e.removeAttribute("contenteditable"))
  c.normalize()
  return c.innerHTML
}
