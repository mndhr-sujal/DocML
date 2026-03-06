import sys
import os
import pypandoc
from PIL import Image

class Converter:
    SUPPORTED_CONVERSIONS = {
        "png": ["png", "jpg", "jpeg", "bmp", "tiff", "webp", "pdf"],
        "jpg": ["jpg", "jpeg", "png", "bmp", "tiff", "webp", "pdf"],
        "jpeg": ["jpg", "jpeg", "png", "bmp", "tiff", "webp", "pdf"],
        "bmp": ["bmp", "png", "jpg", "jpeg", "tiff", "webp", "pdf"],
        "tiff": ["tiff", "png", "jpg", "jpeg", "bmp", "webp", "pdf"],
        "webp": ["webp", "png", "jpg", "jpeg", "bmp", "tiff", "pdf"],
        "md": ["html", "docx", "pdf"],
        "markdown": ["html", "docx", "pdf"],
        "html": ["md", "markdown", "docx", "pdf"],
        "htm": ["md", "markdown", "docx", "pdf"],
        "docx": ["html", "md", "markdown", "pdf"],
        "odt": ["html", "md", "markdown", "pdf"],
        "epub": ["html", "md", "markdown"],
    }

    @staticmethod
    def convert(input_path, output_format):
        output_format = output_format.lower()
        output_path = f"{os.path.splitext(input_path)[0]}_converted.{output_format}"
        ext = os.path.splitext(input_path)[1][1:].lower()
        if ext not in Converter.SUPPORTED_CONVERSIONS or output_format not in Converter.SUPPORTED_CONVERSIONS[ext]:
            print(f"Conversion from '{ext}' to '{output_format}' is NOT supported.")
            return
        try:
            Converter._convert_image(input_path, output_path, output_format)
            print(f"Successfully converted image to: {output_path}")
            return
        except Exception:
            pass
        try:
            Converter._convert_document(input_path, output_path, output_format)
            print(f"Successfully converted document to: {output_path}")
        except Exception as e:
            print(f"Conversion failed: {str(e)}")

    @staticmethod
    def _convert_image(input_path, output_path, output_format):
        with Image.open(input_path) as img:
            if img.mode == 'RGBA' and output_format in ['jpg', 'jpeg', 'pdf']:
                img = img.convert('RGB')
            img.save(output_path)

    @staticmethod
    def _convert_document(input_path, output_path, output_format):
        pypandoc.convert_file(input_path, output_format, outputfile=output_path)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python convert.py <input_path> <output_format>")
        sys.exit(1)
    input_path = sys.argv[1]
    output_format = sys.argv[2]
    Converter.convert(input_path, output_format)