import base64
import html
import json
import re
import shutil
import sys
from pathlib import Path

import fitz  # PyMuPDF
from pylatexenc.latex2text import LatexNodes2Text


class LatexConverter:
    _latex_parser = LatexNodes2Text()

    @staticmethod
    def normalize(latex_str):
        if not latex_str:
            return latex_str

        def fix_mathtt(match):
            content = match.group(1).replace(" ", "")
            return r"\mathrm{" + content + "}"

        latex_str = re.sub(r"\\mathtt\{([^}]+)\}", fix_mathtt, latex_str)
        latex_str = latex_str.replace("=", " = ")
        latex_str = re.sub(r"\s+=\s+", " = ", latex_str)
        latex_str = latex_str.replace(r"\boldmath", r"\mathbf").replace(
            r"\bf", r"\mathbf"
        )
        latex_str = re.sub(
            r"\\frac\s*\\([a-zA-Z]+)(?![a-zA-Z{])", r"\\frac{\\\1}", latex_str
        )
        latex_str = re.sub(r"\\frac\s*\\([^a-zA-Z{])", r"\\frac{\\\1}", latex_str)
        latex_str = re.sub(
            r"\\frac\s*([a-zA-Z0-9])(?![a-zA-Z0-9{])", r"\\frac{\1}", latex_str
        )
        return latex_str

    # Convert latex to unicode
    @staticmethod
    def to_unicode(text_content):
        if not text_content:
            return text_content
        text_content = LatexConverter.normalize(text_content)

        inline_math_pattern = r"\$(.*?)\$"
        if re.search(inline_math_pattern, text_content):

            def replacement(match):
                try:
                    return LatexConverter._latex_parser.latex_to_text(match.group(1))
                except Exception:
                    return match.group(0)

            text_content = re.sub(inline_math_pattern, replacement, text_content)

        if "\\" in text_content or "_{" in text_content or "^{" in text_content:
            input_str = (
                f"${text_content}$"
                if "{" in text_content and "\\" not in text_content
                else text_content
            )
            try:
                return LatexConverter._latex_parser.latex_to_text(input_str)
            except ImportError:
                pass
        return text_content


class BlockRenderer:
    def __init__(self, scale, image_map, imgs_dir):
        self.scale = scale
        self.image_map = image_map
        self.imgs_dir = imgs_dir

    # Filter out text lines that reside inside images or tables
    def is_overlapping(self, line_rect, exclusion_zones):
        lx1, ly1, lx2, ly2 = line_rect
        l_area = (lx2 - lx1) * (ly2 - ly1)
        if l_area <= 0:
            return False
        for ex1, ey1, ex2, ey2 in exclusion_zones:
            ix1, iy1 = max(lx1, ex1), max(ly1, ey1)
            ix2, iy2 = min(lx2, ex2), min(ly2, ey2)
            if ix1 < ix2 and iy1 < iy2:
                if ((ix2 - ix1) * (iy2 - iy1)) / l_area > 0.3:
                    return True
        return False

    def render_formula(self, block):
        label = block.get("block_label")
        bbox = block.get("block_bbox")
        content = block.get("block_content", "").strip().strip("$")
        x1, y1, x2, y2 = [c * self.scale for c in bbox]
        bw, bh = x2 - x1, y2 - y1

        # Generate unicode text for math blocks
        try:
            unicode_text = LatexConverter._latex_parser.latex_to_text(
                LatexConverter.normalize(content)
            )
            fs = max(8, min(bh * 0.8, (bw / (len(unicode_text) or 1)) * 1.8))
            style = "display:flex;align-items:center;justify-content:center;width:100%;height:100%;"
            inner = f"<div style='{style} font-size:{fs}pt;'>{html.escape(unicode_text)}</div>"
            return f"<div class='block cls_{label}' style='left:{x1}pt;top:{y1}pt;width:{bw}pt;height:{bh}pt;'><span class='block-label'>{label}</span>{inner}</div>"
        except ImportError:
            return ""

    def render_text(self, block, all_global_lines, exclusion_zones):
        label = block.get("block_label")
        bbox = block.get("block_bbox")
        x1, y1, x2, y2 = [c * self.scale for c in bbox]
        bw, bh = x2 - x1, y2 - y1

        inner_html = ""
        matched_img = self.image_map.get(
            tuple(map(int, bbox[:4]))
        )  # check if block has image
        if matched_img:
            img_p = self.imgs_dir / matched_img
            if img_p.exists():
                b64 = base64.b64encode(img_p.read_bytes()).decode()
                inner_html = f"<img src='data:image/jpeg;base64,{b64}'>"
                if label in ["chart", "figure", "image", "table"]:
                    return f"<div class='block cls_{label}' style='left:{x1}pt;top:{y1}pt;width:{bw}pt;height:{bh}pt;'><span class='block-label'>{label}</span>{inner_html}</div>"

        block_lines = []
        res = block.get("res", [])
        if isinstance(res, list):
            for line in res:
                poly = line.get("dt_boxes") or line.get("box")
                txt = line.get("text", "")
                if poly and txt:
                    if isinstance(poly[0], list):
                        lx1, ly1, lx2, ly2 = (
                            min(p[0] for p in poly),
                            min(p[1] for p in poly),
                            max(p[0] for p in poly),
                            max(p[1] for p in poly),
                        )
                    else:
                        lx1, ly1, lx2, ly2 = poly
                    block_lines.append({"text": txt, "rect": [lx1, ly1, lx2, ly2]})

        for gl in all_global_lines:
            if gl["used"]:
                continue
            gx1, gy1, gx2, gy2 = gl["rect"]
            cx, cy = (gx1 + gx2) / 2, (gy1 + gy2) / 2
            if bbox[0] <= cx <= bbox[2] and bbox[1] <= cy <= bbox[3]:
                block_lines.append(gl)
                gl["used"] = True

        # Render individual text lines using spatial coordinates
        lines_html = ""
        for line in block_lines:
            lx1, ly1, lx2, ly2 = [c * self.scale for c in line["rect"]]
            if self.is_overlapping((lx1, ly1, lx2, ly2), exclusion_zones):
                continue

            lw, lh = lx2 - lx1, ly2 - ly1
            fs = max(8, lh * 0.75) * (1.3 if label == "doc_title" else 1.0)
            txt = html.escape(LatexConverter.to_unicode(line["text"]))

            # Justify fits text in a line according to its width
            line_style = (
                f"position:absolute;"
                f"left:{lx1 - x1}pt;"
                f"top:{ly1 - y1}pt;"
                f"width:{lw}pt;"
                f"height:{lh}pt;"
                f"font-size:{fs}pt;"
                f"white-space:nowrap;"
                f"text-align:justify;"
                f"text-align-last:justify;"
                f"overflow:visible;"
            )

            lines_html += f"<div style='{line_style}'>{txt}</div>"

        return f"<div class='block cls_{label}' style='left:{x1}pt;top:{y1}pt;width:{bw}pt;height:{bh}pt;'><span class='block-label'>{label}</span>{inner_html + lines_html}</div>"


class HTMLReconstructor:
    def __init__(self, input_path):
        self.input_path = Path(input_path) if input_path else Path(".")
        self.output_dir = Path("./output")
        self.imgs_dir = self.output_dir / "imgs"
        self.image_map = self._load_image_map()

    # Map ocr bounding boxes to pre-extracted image files
    def _load_image_map(self):
        imap = {}
        if self.imgs_dir.exists():
            for f in self.imgs_dir.glob("*.jpg"):
                try:
                    c = [int(p) for p in f.stem.split("_")[-4:]]
                    if len(c) == 4:
                        imap[tuple(c)] = f.name
                except FileNotFoundError:
                    continue
        return imap

    def _get_html_head(self, title):
        return f"""<!DOCTYPE html>
            <html>
            <head>
                <meta charset='utf-8'>
                <title>{html.escape(title)}</title>
                <link href='https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;700&display=swap' rel='stylesheet'>
                <style>
                    * {{ box-sizing: border-box; }}
                    body {{
                        background: #525659; margin: 0; padding: 40px 0;
                        display: flex; flex-direction: column; align-items: center;
                        font-family: 'Times New Roman', 'Noto Sans Devanagari', serif;
                    }}
                    .page {{
                        position: relative; background: white;
                        box-shadow: 0 0 15px rgba(0,0,0,0.4);
                        margin-bottom: 30px;
                        overflow: hidden;
                        flex-shrink: 0;
                        /* Right margin buffer to prevent text clipping */
                        padding-right: 20pt;
                    }}
                    .block {{ position: absolute; pointer-events: all; }}
                    .block img {{ width: 100%; height: 100%; object-fit: contain; }}
                    .block:hover {{ outline: 1pt solid #007bff; background: rgba(0,123,255,0.05); z-index: 100; }}
                    .block-label {{
                        display: none; position: absolute; top: -14pt; left: 0;
                        font-size: 8pt; background: #007bff; color: white;
                        padding: 2pt 5pt; white-space: nowrap; z-index: 101;
                    }}
                    .block:hover .block-label {{ display: block; }}
                    .print-btn {{
                        position: fixed; top: 20px; right: 20px; z-index: 1000;
                        padding: 12px 24px; background: #007bff; color: white;
                        border: none; border-radius: 5px; cursor: pointer;
                    }}
                    @media print {{
                        body {{ background: white; padding: 0; display: block; }}
                        .print-btn {{ display: none; }}
                        .page {{ margin: 0 auto; box-shadow: none; page-break-after: always; padding-right: 0; }}
                    }}
                </style>
            </head>
            <body contenteditable='true' spellcheck='false'>
                <button class='print-btn' onclick='window.print()' contenteditable='false'>Print PDF</button>
            """

    # Reconstruct page-level json to HTML
    def reconstruct(self):
        json_files = sorted(
            [
                f
                for f in self.output_dir.glob("*.json")
                if f.name.startswith(self.input_path.stem)
            ]
        )
        doc = None
        try:
            doc = fitz.open(str(self.input_path))
        except FileNotFoundError:
            pass

        html_content = [self._get_html_head(self.input_path.stem)]

        for i, jfile in enumerate(json_files):
            data = json.loads(jfile.read_text(encoding="utf-8"))
            blocks = data.get("parsing_res_list", [])

            pw, ph = (595.0, 842.0)
            if doc and i < len(doc):
                pw, ph = doc[i].rect.width, doc[i].rect.height

            # Find size document
            max_y = max((b["block_bbox"][3] for b in blocks), default=ph)
            max_x = max((b["block_bbox"][2] for b in blocks), default=pw)

            # Scale document to fit PDF boundary
            scale_w = pw / (max_x * 1.08) if max_x > pw else 1.0
            scale_h = ph / (max_y * 1.05) if max_y > ph else 1.0
            scale = min(scale_w, scale_h)

            renderer = BlockRenderer(scale, self.image_map, self.imgs_dir)
            html_content.append(
                f"<div class='page' style='width:{pw}pt;height:{ph}pt;'>"
            )

            ocr = data.get("overall_ocr_res", {})
            t_list = ocr.get("rec_text") or ocr.get("rec_texts") or []
            b_list = ocr.get("rec_boxes") or ocr.get("dt_boxes") or []
            glines = []
            for t, b in zip(t_list, b_list):
                if not b:
                    continue
                if isinstance(b[0], list):
                    lx1, ly1, lx2, ly2 = (
                        min(p[0] for p in b),
                        min(p[1] for p in b),
                        max(p[0] for p in b),
                        max(p[1] for p in b),
                    )
                else:
                    lx1, ly1, lx2, ly2 = b
                glines.append({"text": t, "rect": [lx1, ly1, lx2, ly2], "used": False})

            excl = [
                [c * scale for c in b["block_bbox"]]
                for b in blocks
                if b["block_label"] in ["image", "figure", "chart", "table", "formula"]
            ]

            for b in blocks:
                if b["block_label"] == "formula":
                    html_content.append(renderer.render_formula(b))
                else:
                    html_content.append(renderer.render_text(b, glines, excl))

            html_content.append("</div>")

        if doc:
            doc.close()

        html_content.extend(["</body></html>"])

        out = self.input_path.parent / f"{self.input_path.stem}_reconstructed.html"
        out.write_text("".join(html_content), encoding="utf-8")

        # Cleanup intermediate json directory
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
        print(f"Done: {out.name}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        HTMLReconstructor(sys.argv[1]).reconstruct()
