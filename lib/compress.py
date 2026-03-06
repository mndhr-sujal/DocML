import sys
import io
import os
import pikepdf
from PIL import Image
import gzip
import shutil
from htmlmin import minify
import py7zr

file_path = sys.argv[1]
class FileCompressor:
    def __init__(self, input_file):
        self.input_file = input_file
        self.file_extension = input_file.lower().split('.')[-1]

    def compress_pdf(self, output_pdf, image_quality=75, max_resolution=1000):
        try:
            with pikepdf.open(self.input_file) as pdf:
                for page in pdf.pages:
                    if '/XObject' in page.Resources: #images are in /XObject
                        xobjects = page.Resources['/XObject']
                        for name, xobj in xobjects.items():
                            if xobj.get('/Subtype') == '/Image':
                                try:
                                    pdf_img = pikepdf.PdfImage(xobj)
                                    if pdf_img.width < 100 and pdf_img.height < 100:
                                        continue

                                    pil_img = pdf_img.as_pil_image()
                                    width, height = pil_img.size
                                    
                                    if max(width, height) > max_resolution:
                                        scale = max_resolution / max(width, height)
                                        new_width = int(width * scale)
                                        new_height = int(height * scale)
                                        pil_img = pil_img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                                    
                                    if pil_img.mode in ('RGBA', 'P', 'LA'):
                                        pil_img = pil_img.convert('RGB')
                                        
                                    img_buffer = io.BytesIO()
                                    pil_img.save(img_buffer, format='JPEG', quality=image_quality, optimize=True)
                                    img_buffer.seek(0)
                                    
                                    new_image = pikepdf.Stream(pdf, img_buffer.read())
                                    new_image.Type = pikepdf.Name("/XObject")
                                    new_image.Subtype = pikepdf.Name("/Image")
                                    new_image.Width = pil_img.width
                                    new_image.Height = pil_img.height
                                    new_image.ColorSpace = pikepdf.Name("/DeviceRGB")
                                    new_image.BitsPerComponent = 8
                                    new_image.Filter = pikepdf.Name("/DCTDecode")
                                    
                                    xobjects[name] = new_image
                                except Exception:
                                    pass

                pdf.remove_unreferenced_resources()
                pdf.save(output_pdf, compress_streams=True)
            print(f"PDF compression completed: {output_pdf}")
        except Exception as e:
            print(f"Error during PDF compression: {e}")

    def compress_image(self, output_image, quality=75, max_resolution=2000):
        try:
            with Image.open(self.input_file) as img:
                width, height = img.size
                if max(width, height) > max_resolution:
                    scale = max_resolution / max(width, height)
                    new_width = int(width * scale)
                    new_height = int(height * scale)
                    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                
                file_format = img.format if img.format else 'JPEG'
                
                if file_format == 'JPEG' or output_image.lower().endswith(('.jpg', '.jpeg')):
                    if img.mode in ('RGBA', 'P', 'LA'):
                        img = img.convert('RGB')
                    file_format = 'JPEG'
                    img.save(output_image, format=file_format, quality=quality, optimize=True)
                    
                elif file_format == 'PNG' or output_image.lower().endswith('.png'):
                    if img.mode != 'P':
                        img = img.quantize(colors=256, method=2) 
                    img.save(output_image, format='PNG', optimize=True)
                
                else:
                     img.save(output_image, format=file_format, quality=quality, optimize=True)
                     
            print(f"Image compression completed: {output_image}")
        except Exception as e:
            print(f"Error during image compression: {e}")

    def compress_text_file(self, output_file):
        try:
            with open(self.input_file, 'rb') as f_in:
                with gzip.open(output_file, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
            print(f"Text file compression completed: {output_file}")
        except Exception as e:
            print(f"Error during text file compression: {e}")

    def compress_html(self, output_file):
        try:
            with open(self.input_file, 'r', encoding='utf-8') as f_in:
                html_content = f_in.read()
            minified_html = minify(html_content, remove_comments=True, reduce_empty_attributes=True)
            with open(output_file, 'w', encoding='utf-8') as f_out:
                f_out.write(minified_html)
            print(f"Html compression completed: {output_file}")
        except Exception as e:
            print(f"Error during html compression: {e}")

    def compress_to_7z(self, output_7z):
        try:
            with py7zr.SevenZipFile(output_7z, mode='w') as archive:
                if os.path.isdir(self.input_file):
                    archive.writeall(self.input_file, arcname=os.path.basename(self.input_file))
                else:
                    archive.write(self.input_file, arcname=os.path.basename(self.input_file))
            print(f"7z file compression completed: {output_7z}")
        except Exception as e:
            print(f"Error during 7z compression: {e}")

    def compress_file(self):
        if self.file_extension == 'pdf':
            self.compress_pdf(f"{os.path.splitext(self.input_file)[0]}_compressed.pdf")
        elif self.file_extension in ['jpg', 'jpeg', 'png', 'bmp']:
            self.compress_image(f"{os.path.splitext(self.input_file)[0]}_compressed.{self.file_extension}", quality=70)
        elif self.file_extension == 'txt':
            self.compress_text_file(f"{os.path.splitext(self.input_file)[0]}_compressed.txt.gz")
        elif self.file_extension == 'html':
            self.compress_html(f"{os.path.splitext(self.input_file)[0]}_compressed.html")
        else:
            self.compress_to_7z(f"{os.path.splitext(self.input_file)[0]}_compressed.7z")

if __name__ == "__main__":
    compressor = FileCompressor(file_path)
    compressor.compress_file()