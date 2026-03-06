from paddlex import create_pipeline
from pathlib import Path
import time
import sys

start_time = time.time()
pipeline_path = str(Path(__file__).parent / "PP-StructureV3.yaml")
pipeline = create_pipeline(pipeline=pipeline_path)

if len(sys.argv) < 2:
    print("Usage: python ocr.py <input_file>")
    sys.exit(1)

input_file = sys.argv[1]
output_path = Path("./output")

output = pipeline.predict(
    input=input_file,
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False
)

markdown_list = []
markdown_images = []

for res in output:
    md_info = res.markdown
    markdown_list.append(md_info)
    markdown_images.append(md_info.get("markdown_images", {}))
    res.save_to_json("./output/")

for item in markdown_images:
    if item:
        for path, image in item.items():
            file_path = output_path / path
            file_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(file_path)

processing_time = time.time() - start_time
print(f"Processing time: {processing_time:.2f} seconds")