"""Convert a DOCX manuscript to Markdown while retaining Office equations as MathML.

The emitted MathML is transformed with Microsoft's OMML2MML stylesheet that ships
with Word, avoiding lossy OCR or hand-transcription of equations.
"""
from __future__ import annotations

import argparse
import html
import re
import shutil
import zipfile
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph
from lxml import etree

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
M_NS = "http://schemas.openxmlformats.org/officeDocument/2006/math"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS = {"w": W_NS, "m": M_NS, "r": R_NS}


def clean_text(value: str) -> str:
    value = value.replace("\u00a0", " ").replace("\u00ad", "")
    value = value.replace("\r", "").replace("\n", " ").replace("\t", " ")
    return re.sub(r" {2,}", " ", value)


def rel_target(document: Document, rel_id: str) -> str | None:
    relation = document.part.rels.get(rel_id)
    if relation is None or not hasattr(relation.target_part, "partname"):
        return None
    return str(relation.target_part.partname).lstrip("/")


def convert_math(element: etree._Element, transform: etree.XSLT) -> str:
    """Return source-faithful MathML for an OMML node."""
    result = transform(etree.fromstring(etree.tostring(element)))
    rendered = etree.tostring(result, encoding="unicode", method="xml")
    # The transform includes its own XML declaration; raw Markdown needs only math.
    return re.sub(r"^<\?xml[^>]*>\s*", "", rendered).strip()


def paragraph_markdown(paragraph: Paragraph, document: Document, transform: etree.XSLT, asset_prefix: str) -> str:
    def render_children(parent: etree._Element) -> list[str]:
        pieces: list[str] = []
        for child in parent:
            pieces.extend(render_node(child))
        return pieces

    def render_node(child: etree._Element) -> list[str]:
        pieces: list[str] = []
        if child.tag == qn("w:r"):
            text_parts: list[str] = []
            for node in child:
                if node.tag in (qn("w:t"), qn("w:delText")):
                    text_parts.append(node.text or "")
                elif node.tag == qn("w:tab"):
                    text_parts.append(" ")
                elif node.tag in (qn("w:br"), qn("w:cr")):
                    text_parts.append("  \n")
                elif node.tag == qn("w:drawing"):
                    embeds = node.xpath(".//a:blip/@r:embed")
                    for rel_id in embeds:
                        target = rel_target(document, rel_id)
                        if target:
                            pieces.append(f"![]({asset_prefix}/{Path(target).name})")
            text = clean_text("".join(text_parts))
            if text:
                if child.find(qn("w:rPr") + "/" + qn("w:b")) is not None:
                    text = f"**{text}**"
                elif child.find(qn("w:rPr") + "/" + qn("w:i")) is not None:
                    text = f"*{text}*"
                pieces.append(text)
        elif child.tag in (qn("m:oMath"), qn("m:oMathPara")):
            pieces.append(convert_math(child, transform))
        elif child.tag in (qn("w:hyperlink"), qn("w:ins")):
            pieces.extend(render_children(child))
        elif child.tag == qn("w:del"):
            deleted = "".join(render_children(child)).strip()
            if deleted:
                pieces.append(f"~~{deleted}~~")
        return pieces

    content = "".join(render_children(paragraph._p)).strip()
    if not content:
        return ""
    style = (paragraph.style.name or "").lower()
    if style.startswith("heading"):
        match = re.search(r"(\d+)", style)
        return f"{'#' * min(int(match.group(1)) if match else 1, 6)} {content}"
    if "title" in style:
        return f"# {content}"
    if "list" in style or paragraph._p.pPr is not None and paragraph._p.pPr.numPr is not None:
        return f"- {content}"
    return content


def table_markdown(table: Table, document: Document, transform: etree.XSLT, asset_prefix: str) -> str:
    rows: list[list[str]] = []
    for row in table.rows:
        cells: list[str] = []
        for cell in row.cells:
            content = "<br>".join(
                paragraph_markdown(p, document, transform, asset_prefix)
                for p in cell.paragraphs
                if paragraph_markdown(p, document, transform, asset_prefix)
            )
            cells.append(content.replace("|", "\\|"))
        rows.append(cells)
    if not rows:
        return ""
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    header = rows[0]
    output = ["| " + " | ".join(header) + " |", "| " + " | ".join(["---"] * width) + " |"]
    output += ["| " + " | ".join(row) + " |" for row in rows[1:]]
    return "\n".join(output)


def iter_body_blocks(document: Document):
    body = document.element.body
    for child in body.iterchildren():
        if child.tag == qn("w:p"):
            yield Paragraph(child, document)
        elif child.tag == qn("w:tbl"):
            yield Table(child, document)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    assets = output.parent / f"{output.stem}_assets"
    assets.mkdir(exist_ok=True)
    with zipfile.ZipFile(source) as archive:
        for item in archive.namelist():
            if item.startswith("word/media/") and not item.endswith("/"):
                with archive.open(item) as read, (assets / Path(item).name).open("wb") as write:
                    shutil.copyfileobj(read, write)
    xsl = Path(r"C:\Program Files\Microsoft Office\root\Office16\OMML2MML.XSL")
    transform = etree.XSLT(etree.parse(str(xsl)))
    document = Document(str(source))
    blocks = ["<!-- Generated from the associated DOCX. Equations are source-faithful MathML transformed from Word OMML. -->", ""]
    for block in iter_body_blocks(document):
        if isinstance(block, Paragraph):
            text = paragraph_markdown(block, document, transform, assets.name)
        else:
            text = table_markdown(block, document, transform, assets.name)
        if text:
            blocks.extend([text, ""])
    output.write_text("\n".join(blocks).rstrip() + "\n", encoding="utf-8")
    print(f"Wrote {output}")
    print(f"Assets: {assets}")


if __name__ == "__main__":
    main()
