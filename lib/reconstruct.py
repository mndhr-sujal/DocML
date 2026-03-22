import base64
import html
import json
import shutil
import sys
from pathlib import Path
from textwrap import dedent

import fitz  # PyMuPDF


class BlockRenderer:
    def __init__(
        self,
        scale,
        offset_x,
        offset_y,
        min_x,
        min_y,
        image_map,
        imgs_dir,
        use_table=False,
        use_formula=False,
    ):
        self.scale = scale
        self.offset_x = offset_x
        self.offset_y = offset_y
        self.min_x = min_x
        self.min_y = min_y
        self.image_map = image_map
        self.imgs_dir = imgs_dir
        self.use_table = use_table
        self.use_formula = use_formula

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

    def render_text(self, block, all_global_lines, exclusion_zones):
        label = block.get("block_label")
        bbox = block.get("block_bbox")
        x1, y1, x2, y2 = [coordinate * self.scale for coordinate in bbox]
        block_width, block_height = x2 - x1, y2 - y1
        x1_shifted = ((bbox[0] - self.min_x) * self.scale) + self.offset_x
        y1_shifted = ((bbox[1] - self.min_y) * self.scale) + self.offset_y

        inner_html = ""
        matched_img = self.image_map.get(
            tuple(map(int, bbox[:4]))
        )  # check if block has image
        if matched_img:
            image_path = self.imgs_dir / matched_img
            if image_path.exists():
                base64_img = base64.b64encode(image_path.read_bytes()).decode()
                image_only_labels = ["chart", "figure", "image"]
                if not self.use_table:
                    image_only_labels.append("table")
                if not self.use_formula:
                    image_only_labels.append("formula")

                if label in image_only_labels:
                    inner_html = f"<img src='data:image/jpeg;base64,{base64_img}'>"
                    return f"<div class='block cls_{label}' style='left:{x1_shifted}pt;top:{y1_shifted}pt;width:{block_width}pt;height:{block_height}pt;'><span class='block-label'>{label}</span>{inner_html}</div>"

        block_lines = []
        for global_line in all_global_lines:
            if global_line["used"]:
                continue
            gx1, gy1, gx2, gy2 = global_line["rect"]
            center_x, center_y = (gx1 + gx2) / 2, (gy1 + gy2) / 2
            if bbox[0] <= center_x <= bbox[2] and bbox[1] <= center_y <= bbox[3]:
                block_lines.append(global_line)
                global_line["used"] = True

        # Fallback to block level ocr if no global lines found
        if not block_lines:
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

        # Render individual text lines using spatial coordinates
        lines_html = ""
        for line in block_lines:
            lx1, ly1, lx2, ly2 = [
                coordinate * self.scale for coordinate in line["rect"]
            ]
            if self.is_overlapping((lx1, ly1, lx2, ly2), exclusion_zones):
                continue

            line_width, line_height = lx2 - lx1, ly2 - ly1
            fontsize = max(8, line_height * 0.75) * (
                1.3 if label == "doc_title" else 1.0
            )
            escaped_text = html.escape(line["text"])

            # Justify fits text in a line according to its width
            line_style = (
                f"position:absolute;"
                f"left:{lx1 - x1}pt;"
                f"top:{ly1 - y1}pt;"
                f"width:{line_width}pt;"
                f"height:{line_height}pt;"
                f"font-size:{fontsize}pt;"
                f"white-space:nowrap;"
                f"text-align:justify;"
                f"text-align-last:justify;"
                f"overflow:visible;"
            )

            lines_html += f"<div style='{line_style}'>{escaped_text}</div>"

        return f"<div class='block cls_{label}' style='left:{x1_shifted}pt;top:{y1_shifted}pt;width:{block_width}pt;height:{block_height}pt;'><span class='block-label'>{label}</span>{inner_html + lines_html}</div>"


class HTMLReconstructor:
    def __init__(self, input_path, use_table=False, use_formula=False):
        self.input_path = Path(input_path) if input_path else Path(".")
        self.output_dir = Path("./output")
        self.imgs_dir = self.output_dir / "imgs"
        self.image_map = self._load_image_map()
        self.use_table = use_table
        self.use_formula = use_formula

    # Map ocr bounding boxes to pre-extracted image files
    def _load_image_map(self):
        image_mapping = {}
        if self.imgs_dir.exists():
            for file_path in self.imgs_dir.glob("*.jpg"):
                try:
                    coords = [int(point) for point in file_path.stem.split("_")[-4:]]
                    if len(coords) == 4:
                        image_mapping[tuple(coords)] = file_path.name
                except FileNotFoundError:
                    continue
        return image_mapping

    def _get_html_head(self, title):
        return dedent(f"""\
            <!DOCTYPE html>
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
            """)

    # Reconstruct page-level json to HTML
    def reconstruct(self):
        json_files = sorted(
            [
                json_file
                for json_file in self.output_dir.glob("*.json")
                if json_file.name.startswith(self.input_path.stem)
            ]
        )
        pdf_document = None
        try:
            pdf_document = fitz.open(str(self.input_path))
        except FileNotFoundError:
            pass

        html_content = [self._get_html_head(self.input_path.stem)]

        for file_index, json_file in enumerate(json_files):
            data = json.loads(json_file.read_text(encoding="utf-8"))
            blocks = data.get("parsing_res_list", [])

            page_width, page_height = (595.0, 842.0)
            if pdf_document and file_index < len(pdf_document):
                page_width, page_height = (
                    pdf_document[file_index].rect.width,
                    pdf_document[file_index].rect.height,
                )

            # Find size of document
            min_x = min((block["block_bbox"][0] for block in blocks), default=0)
            min_y = min((block["block_bbox"][1] for block in blocks), default=0)
            max_x = max(
                (block["block_bbox"][2] for block in blocks), default=page_width
            )
            max_y = max(
                (block["block_bbox"][3] for block in blocks), default=page_height
            )

            content_width = max_x - min_x
            content_height = max_y - min_y

            # Scale document to fit PDF boundary
            scale_width = (
                (page_width * 0.9) / content_width if content_width > 0 else 1.0
            )
            scale_height = (
                (page_height * 0.9) / content_height if content_height > 0 else 1.0
            )
            scale = min(scale_width, scale_height)

            offset_x = (
                (page_width - (content_width * scale)) / 2 if content_width > 0 else 0
            )
            offset_y = (
                (page_height - (content_height * scale)) / 2
                if content_height > 0
                else 0
            )

            renderer = BlockRenderer(
                scale,
                offset_x,
                offset_y,
                min_x,
                min_y,
                self.image_map,
                self.imgs_dir,
                self.use_table,
                self.use_formula,
            )
            html_content.append(
                f"<div class='page' style='width:{page_width}pt;height:{page_height}pt;'>"
            )

            ocr_results = data.get("overall_ocr_res", {})
            text_list = (
                ocr_results.get("rec_text") or ocr_results.get("rec_texts") or []
            )
            box_list = ocr_results.get("rec_boxes") or ocr_results.get("dt_boxes") or []
            global_lines = []
            for text_val, box_val in zip(text_list, box_list):
                if not box_val:
                    continue
                if isinstance(box_val[0], list):
                    lx1, ly1, lx2, ly2 = (
                        min(p[0] for p in box_val),
                        min(p[1] for p in box_val),
                        max(p[0] for p in box_val),
                        max(p[1] for p in box_val),
                    )
                else:
                    lx1, ly1, lx2, ly2 = box_val
                global_lines.append(
                    {"text": text_val, "rect": [lx1, ly1, lx2, ly2], "used": False}
                )

            excl_labels = ["image", "figure", "chart"]
            if not self.use_table:
                excl_labels.append("table")
            if not self.use_formula:
                excl_labels.append("formula")

            exclusion_zones = [
                [coordinate * scale for coordinate in block["block_bbox"]]
                for block in blocks
                if block["block_label"] in excl_labels
            ]

            for block in blocks:
                html_content.append(
                    renderer.render_text(block, global_lines, exclusion_zones)
                )

            html_content.append("</div>")

        if pdf_document:
            pdf_document.close()

        html_content.extend(["</body></html>"])

        out = self.input_path.parent / f"{self.input_path.stem}_reconstructed.html"
        out.write_text("".join(html_content), encoding="utf-8")

        # Cleanup intermediate json directory
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
        print(f"Done: {out.name}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        use_table = "--table" in sys.argv
        use_formula = "--formula" in sys.argv
        input_path = [arg for arg in sys.argv[1:] if not arg.startswith("--")][0]
        HTMLReconstructor(input_path, use_table, use_formula).reconstruct()
