import json
import os
import re
import sys
import html
from pathlib import Path
import base64
import shutil
import fitz
from pylatexenc.latex2text import LatexNodes2Text

input_path = sys.argv[1]
output_path = f"{os.path.splitext(input_path)[0]}"

def normalize_latex(latex_str):
    if not latex_str: return latex_str
    def fix_mathtt(match):
        content = match.group(1)
        fixed = content.replace(" ", "")
        return r"\mathrm{" + fixed + "}"
    latex_str = re.sub(r"\\mathtt\{([^}]+)\}", fix_mathtt, latex_str)
    latex_str = latex_str.replace("=", " = ")
    latex_str = re.sub(r"\s+=\s+", " = ", latex_str)
    latex_str = latex_str.replace(r"\boldmath", r"\mathbf")
    latex_str = latex_str.replace(r"\bf", r"\mathbf")
    latex_str = re.sub(r"\\frac\s*\\([a-zA-Z]+)(?![a-zA-Z{])", r"\\frac{\\\1}", latex_str)
    latex_str = re.sub(r"\\frac\s*\\([^a-zA-Z{])", r"\\frac{\\\1}", latex_str)
    latex_str = re.sub(r"\\frac\s*([a-zA-Z0-9])(?![a-zA-Z0-9{])", r"\\frac{\1}", latex_str)
    return latex_str

def convert_latex_to_unicode(text_content):
    if not text_content:
        return text_content
    text_content = normalize_latex(text_content)
    pattern = r'\$(.*?)\$'
    if re.search(pattern, text_content):
        def replacement(match):
            latex_str = match.group(1)
            try:
                return LatexNodes2Text().latex_to_text(latex_str)
            except:
                return match.group(0)
        text_content = re.sub(pattern, replacement, text_content)
    if "\\" in text_content:
        try:
             return LatexNodes2Text().latex_to_text(text_content)
        except:
             pass             
    if "_{" in text_content or "^{" in text_content:
        try:
             return LatexNodes2Text().latex_to_text(f"${text_content}$")
        except:
             pass
             
    return text_content

def get_page_size(pdf_path, page_index):
    if os.path.exists(pdf_path):
        try:
            doc = fitz.open(pdf_path)
            if page_index < len(doc):
                page = doc[page_index]
                rect = page.rect
                return rect.width, rect.height
        except Exception as e:
            print(f"Error reading PDF dimensions: {e}")
    return None, None

def reconstruct_layout(input_file_path=None):
    output_dir = Path("./output")
    input_dir = Path(".")
    output_base_dir = Path(input_file_path).parent if input_file_path else input_dir
    imgs_dir = output_dir / "imgs"
    image_map = {}
    if imgs_dir.exists():
        for img_file in imgs_dir.glob("*.jpg"):
            try:
                parts = img_file.stem.split('_')
                if len(parts) >= 4:
                    coords = [int(p) for p in parts[-4:]]
                    if len(coords) == 4:
                        image_map[tuple(coords)] = img_file.name
            except ValueError:
                continue
    json_files = list(output_dir.glob("*_res.json"))
    grouped_files = {}
    for json_file in json_files:
        match = re.match(r"(.+)_(\d+)_res\.json", json_file.name)
        if match:
            base_name = match.group(1)
            page_index = int(match.group(2))
        else:
            match = re.match(r"(.+)_res\.json", json_file.name)
            if match:
                base_name = match.group(1)
                page_index = 0
            else:
                continue
        if base_name not in grouped_files:
            grouped_files[base_name] = []
        grouped_files[base_name].append((page_index, json_file))
    if not grouped_files:
        print("No matching files found.")
        return
    for base_name, files in grouped_files.items():
        files.sort(key=lambda x: x[0])
        print(f"Processing {base_name} with {len(files)} pages")
        pdf_path = output_base_dir / f"{base_name}.pdf"
        if not pdf_path.exists():
             pass
        html_content = []
        html_content.append("<!DOCTYPE html>")
        html_content.append("<html>")
        html_content.append("<head>")
        html_content.append("<meta charset='utf-8'>")
        html_content.append(f"<title>{base_name} Reconstruction</title>")
        html_content.append("<link rel='preconnect' href='https://fonts.googleapis.com'>")
        html_content.append("<link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>")
        html_content.append("<link href='https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;700&display=swap' rel='stylesheet'>")
        html_content.append("<style>")
        html_content.append("""
            body { font-family: 'Times New Roman', 'Noto Sans Devanagari', serif; background: #e0e0e0; margin: 0; padding: 20px; }
            .page { 
                position: relative; 
                background: white; 
                box-shadow: 0 2px 10px rgba(0,0,0,0.2); 
                margin: 0 auto 30px auto; 
                overflow: hidden; 
            }
            .block { 
                position: absolute; 
                box-sizing: border-box; 
                overflow: visible;
                white-space: normal;
                word-wrap: break-word;
            }
            .block img {
                width: 100%;
                height: 100%;
                object-fit: contain;
                display: block;
            }
            .block:hover {
                outline: 2px solid blue;
                z-index: 10;
                background-color: rgba(255, 255, 255, 0.1);
            }
            .block-label {
                display: none; 
                position: absolute;
                top: 0; right: 0;
                font-size: 8px;
                background: red;
                color: white;
            }
            .block:hover .block-label { display: block; }
            .cls_header, .cls_footer { color: #666; font-family: sans-serif; font-size: 10px; }
            .cls_text { 
                text-align: justify; 
                font-family: 'Times New Roman', 'Noto Sans Devanagari', serif;
                white-space: pre-wrap;
                line-height: 1.25;
            }
        """)
        html_content.append("</style>")
        html_content.append("</head>")
        html_content.append("<body>")
        for page_idx, json_file in files:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            res_list = data.get("parsing_res_list", [])
            width, height = get_page_size(pdf_path, page_idx)
            if width is None or height is None:
                width, height = 595, 842 
            min_x, min_y = float('inf'), float('inf')
            max_x, max_y = 0, 0
            has_content = False
            for item in res_list:
                bbox = item.get("block_bbox")
                if bbox:
                    min_x = min(min_x, bbox[0])
                    min_y = min(min_y, bbox[1])
                    max_x = max(max_x, bbox[2])
                    max_y = max(max_y, bbox[3])
                    has_content = True
            scale = 1.0
            if has_content:
                estimated_json_width = max_x + min_x if min_x > 0 else max_x
                ratio_w = estimated_json_width / width
                scale = 1.0 / ratio_w if ratio_w > 0 else 1.0
                if max_y * scale > height:
                    scale_h = height / (max_y * 1.05)
                    if scale_h < scale:
                        scale = scale_h
            html_content.append(f"<div class='page' style='width: {width}px; height: {height}px;'>")
            overall_ocr = data.get("overall_ocr_res", {})
            global_texts = overall_ocr.get("rec_text", []) or overall_ocr.get("rec_texts", [])
            global_boxes = overall_ocr.get("rec_boxes", []) or overall_ocr.get("dt_boxes", [])
            all_global_lines = []
            if len(global_texts) == len(global_boxes):
                for i, (txt, poly) in enumerate(zip(global_texts, global_boxes)):
                     if not poly: continue
                     if isinstance(poly[0], list):
                        xs = [p[0] for p in poly]
                        ys = [p[1] for p in poly]
                        gx1, gy1, gx2, gy2 = min(xs), min(ys), max(xs), max(ys)
                     else:
                        gx1, gy1, gx2, gy2 = poly[0], poly[1], poly[2], poly[3]
                     all_global_lines.append({
                         'id': i,
                         'text': txt,
                         'rect': [gx1, gy1, gx2, gy2],
                         'used': False
                     })
            exclusion_rects = []
            for item in data.get("parsing_res_list", []):
                if item.get("block_label") in ['image', 'figure', 'chart', 'header_image', 'table', 'formula']:
                     bbox = item.get("block_bbox")
                     if bbox:
                         x1, y1, x2, y2 = [c * scale for c in bbox]
                         exclusion_rects.append((x1, y1, x2, y2))

            def is_overlapping_exclusion(line_rect, exclusion_list):
                 lx1, ly1, lx2, ly2 = line_rect
                 l_area = (lx2 - lx1) * (ly2 - ly1)
                 if l_area <= 0: return False
                 for ex1, ey1, ex2, ey2 in exclusion_list:
                     ix1 = max(lx1, ex1)
                     iy1 = max(ly1, ey1)
                     ix2 = min(lx2, ex2)
                     iy2 = min(ly2, ey2)
                     
                     if ix1 < ix2 and iy1 < iy2:
                         inter = (ix2 - ix1) * (iy2 - iy1)
                         if inter / l_area > 0.3: 
                             return True
                 return False

            for item in data.get("parsing_res_list", []):
                label = item.get("block_label")
                bbox = item.get("block_bbox")
                content = item.get("block_content")
                if not bbox:
                    continue
                x1 = bbox[0] * scale
                y1 = bbox[1] * scale
                x2 = bbox[2] * scale
                y2 = bbox[3] * scale
                block_width = x2 - x1
                block_height = y2 - y1
                orig_bbox_tuple = tuple(map(int, bbox[:4]))
                matched_img = image_map.get(orig_bbox_tuple)
                inner_html = ""
                has_image = False
                if label == 'formula':
                     latex_str = content.strip()
                     if latex_str.startswith("$$") and latex_str.endswith("$$"):
                         latex_str = latex_str[2:-2]
                     elif latex_str.startswith("$") and latex_str.endswith("$"):
                         latex_str = latex_str[1:-1]
                     try:
                         latex_str = normalize_latex(latex_str)
                         unicode_text = LatexNodes2Text().latex_to_text(latex_str)
                         has_newline = '\n' in unicode_text
                         base_style = "display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; overflow: visible;"
                         if has_newline:
                             base_style += " white-space: pre-wrap; text-align: center; flex-direction: column;"
                             lines = unicode_text.split('\n')
                             max_line_char = max([len(l) for l in lines]) if lines else 1
                             fs_h = (block_height / len(lines)) * 0.8
                             fs_w = (block_width / max_line_char) * 1.8
                             form_fs = min(fs_h, fs_w)
                             form_fs = max(8, min(form_fs, 30))
                         else:
                             base_style += " white-space: nowrap;"
                             char_count = len(unicode_text)
                             fs_w = (block_width / char_count) * 1.8 if char_count > 0 else 20
                             fs_h = block_height * 0.8
                             form_fs = min(fs_h, fs_w)
                             form_fs = max(10, min(form_fs, 30))
                         inner_html = f"<div style='{base_style} font-size: {form_fs}px;'>{html.escape(unicode_text)}</div>"
                         style = f"left: {x1}px; top: {y1}px; width: {block_width}px; height: {block_height}px; font-family: 'Times New Roman', 'Noto Sans Devanagari', serif;"
                         html_content.append(f"""
                        <div class='block cls_{label}' style='{style}'>
                            <span class='block-label'>{label}</span>
                            {inner_html}
                        </div>
                        """)
                         continue
                     except Exception as e:
                         pass
                block_lines = []
                res_data = item.get("res")
                if res_data:
                    if isinstance(res_data, list):
                        for line in res_data:
                            poly = line.get("dt_boxes", []) or line.get("box", [])
                            txt = line.get("text", "")
                            if not poly or not txt: continue
                            if isinstance(poly[0], list):
                                xs = [p[0] for p in poly]
                                ys = [p[1] for p in poly]
                                lx1, ly1, lx2, ly2 = min(xs), min(ys), max(xs), max(ys)
                            else:
                                lx1, ly1, lx2, ly2 = poly
                            block_lines.append({'text': txt, 'rect': [lx1, ly1, lx2, ly2], 'source': 'res'})
                    elif isinstance(res_data, dict):
                        rec_texts = res_data.get("rec_texts", [])
                        dt_boxes = res_data.get("dt_boxes", [])
                        if len(rec_texts) == len(dt_boxes):
                             for txt, poly in zip(rec_texts, dt_boxes):
                                 xs = [p[0] for p in poly]
                                 ys = [p[1] for p in poly]
                                 lx1, ly1, lx2, ly2 = min(xs), min(ys), max(xs), max(ys)
                                 block_lines.append({'text': txt, 'rect': [lx1, ly1, lx2, ly2], 'source': 'res'})

                if not block_lines and label == 'text' and content and len(content) > 5:
                     bx1, by1, bx2, by2 = bbox
                     matched_g_count = 0
                     for g_line in all_global_lines:
                        if g_line['used']: continue
                        lx1, ly1, lx2, ly2 = g_line['rect']
                        cx, cy = (lx1 + lx2) / 2, (ly1 + ly2) / 2
                        if bx1 <= cx <= bx2 and by1 <= cy <= by2:
                            matched_g_count += 1
                     should_fallback = True
                     if matched_g_count > 0:
                         avg_line_h = block_height / matched_g_count
                         if avg_line_h < 25.0:
                             should_fallback = False
                     if should_fallback:
                         for g_line in all_global_lines:
                            if g_line['used']: continue
                            lx1, ly1, lx2, ly2 = g_line['rect']
                            ix1 = max(bx1, lx1)
                            iy1 = max(by1, ly1)
                            ix2 = min(bx2, lx2)
                            iy2 = min(by2, ly2)
                            if ix1 < ix2 and iy1 < iy2:
                                inter_area = (ix2 - ix1) * (iy2 - iy1)
                                line_area = (lx2 - lx1) * (ly2 - ly1)
                                if line_area > 0 and (inter_area / line_area) > 0.2:
                                    g_line['used'] = True
                         final_content = convert_latex_to_unicode(content)
                         fs_blk = max(10, block_height * 0.035) 
                         if label == 'doc_title': fs_blk *= 1.3
                         style_str = f"left: {x1}px; top: {y1}px; width: {block_width}px; height: {block_height}px; font-size: {fs_blk}px; font-family: 'Times New Roman', 'Noto Sans Devanagari', serif; text-align: justify; white-space: pre-wrap; overflow: visible;"
                         inner_html = f"<div class='cls_text_fallback' style='{style_str}'>{html.escape(final_content)}</div>"
                         html_content.append(f"<div class='block cls_{label}' style='position:absolute; {style_str}'>{inner_html}</div>")
                         continue
                bx1, by1, bx2, by2 = bbox
                for g_line in all_global_lines:
                    if g_line['used']: continue
                    lx1, ly1, lx2, ly2 = g_line['rect']
                    cx = (lx1 + lx2) / 2
                    cy = (ly1 + ly2) / 2
                    if bx1 <= cx <= bx2 and by1 <= cy <= by2:
                        is_dupe = False
                        norm_g_txt = g_line['text'].strip().lower().replace(" ", "")
                        for b_line in block_lines:
                            norm_b_txt = b_line['text'].strip().lower().replace(" ", "")
                            if norm_g_txt == norm_b_txt:
                                is_dupe = True
                                break
                        if not is_dupe:
                            block_lines.append({
                                'text': g_line['text'],
                                'rect': g_line['rect'],
                                'source': 'global'
                            })
                        g_line['used'] = True 
                filtered_block_lines = []
                for line in block_lines:
                     lx1, ly1, lx2, ly2 = line['rect']
                     slx1, sly1, slx2, sly2 = lx1 * scale, ly1 * scale, lx2 * scale, ly2 * scale
                     if not is_overlapping_exclusion((slx1, sly1, slx2, sly2), exclusion_rects):
                         filtered_block_lines.append(line)
                block_lines = filtered_block_lines
                if matched_img:
                    img_path_obj = imgs_dir / matched_img
                    if img_path_obj.exists():
                        try:
                            with open(img_path_obj, "rb") as img_file:
                                b64_string = base64.b64encode(img_file.read()).decode('utf-8')
                                mime_type = "image/jpeg"
                                if matched_img.lower().endswith(".png"): mime_type = "image/png"
                                
                                inner_html = f"<img src='data:{mime_type};base64,{b64_string}' alt='{label}'>"
                                has_image = True
                        except Exception as e:
                            print(f"Error embedding image {matched_img}: {e}")
                            inner_html = f"<!-- Image embedding failed -->"
                    else:
                         inner_html = f"<!-- Image file missing -->"
                use_image_only = label in ['chart', 'figure', 'image', 'header_image', 'table'] and has_image
                if block_lines and not use_image_only:
                    stripped_content = content.strip() if content else ""
                    is_header_marker = stripped_content.startswith("#")
                    has_newline = "\n" in stripped_content
                    is_bold_block = False
                    if is_header_marker or stripped_content.startswith("**") or "<b>" in str(content) or "<strong>" in str(content):
                        is_bold_block = True                        
                    is_italic_block = False
                    if stripped_content.startswith("*") and not stripped_content.startswith("**"):
                        is_italic_block = True
                    lines_html = ""
                    for i, line in enumerate(block_lines):
                        lx1, ly1, lx2, ly2 = line['rect']
                        slx1, sly1, slx2, sly2 = lx1 * scale, ly1 * scale, lx2 * scale, ly2 * scale
                        slw = slx2 - slx1
                        slh = sly2 - sly1
                        rel_x = slx1 - x1
                        rel_y = sly1 - y1
                        line_fs = max(8, slh * 0.75)
                        if label == 'doc_title':
                            line_fs *= 1.3
                        current_line_style = ""
                        should_bold = False
                        if is_bold_block:
                            if is_header_marker and has_newline:
                                if i == 0:
                                    should_bold = True
                            else:
                                should_bold = True
                        if should_bold:
                            current_line_style += " font-weight: bold;"
                        if is_italic_block:
                            current_line_style += " font-style: italic;"
                        final_text = convert_latex_to_unicode(line['text'])
                        lines_html += f"<div class='cls_text_line' style='left: {rel_x}px; top: {rel_y}px; width: {slw}px; height: {slh}px; font-size: {line_fs}px; position: absolute; text-align: justify; text-align-last: justify; white-space: nowrap; overflow: visible; font-family: \"Times New Roman\", \"Noto Sans Devanagari\", serif;{current_line_style}'>{html.escape(final_text)}</div>"
                    inner_html += lines_html 
                elif not use_image_only:
                     pass
                style = f"left: {x1}px; top: {y1}px; width: {block_width}px; height: {block_height}px;"
                if not use_image_only and not block_lines:
                      if 'title' in label:
                          style += " font-size: 20px; font-weight: bold;"
                      else:
                          style += " font-size: 12px;"
                html_content.append(f"""
                <div class='block cls_{label}' style='{style}'>
                    <span class='block-label'>{label}</span>
                    {inner_html}
                </div>
                """)
            for g_line in all_global_lines:
                if not g_line['used']:
                    lx1, ly1, lx2, ly2 = g_line['rect']
                    slx1, sly1, slx2, sly2 = lx1 * scale, ly1 * scale, lx2 * scale, ly2 * scale
                    slw = slx2 - slx1
                    slh = sly2 - sly1
                    line_fs = max(8, slh * 0.75) 
                    if not is_overlapping_exclusion((slx1, sly1, slx2, sly2), exclusion_rects):
                         final_text = convert_latex_to_unicode(g_line['text'])
                         html_content.append(f"<div class='cls_text_line cls_orphan' style='left: {slx1}px; top: {sly1}px; width: {slw}px; height: {slh}px; font-size: {line_fs}px; position: absolute; text-align: justify; text-align-last: justify; white-space: nowrap; overflow: visible; font-family: \"Times New Roman\", \"Noto Sans Devanagari\", serif; color: red;'>{html.escape(final_text)}</div>")
            html_content.append("</div>")
        html_content.append("</body>")
        html_content.append("</html>")
        output_filename = output_base_dir / f"{base_name}_reconstructed.html"
        with open(output_filename, 'w', encoding='utf-8') as f:
            f.write("\n".join(html_content))
        print(f"Saved reconstruction to {output_filename}")
    if output_dir.exists():
        shutil.rmtree(output_dir)

if __name__ == "__main__":
    input_file_path = sys.argv[1] if len(sys.argv) > 1 else None
    reconstruct_layout(input_file_path)