import io
import os
import shutil
import threading
import time
from typing import Any, List, Optional

import chromadb
import fitz  # PyMuPDF
import uvicorn
from bs4 import BeautifulSoup
from chromadb.config import Settings  # satisfying linter smh
from docx import Document
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from langchain_text_splitters import RecursiveCharacterTextSplitter
from llama_cpp import Llama
from pydantic import BaseModel

PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))
MODELS_DIR = os.path.join(PROJECT_ROOT, "models")
CHROMA_DB_DIR = os.path.join(PROJECT_ROOT, "chroma_db")
EMBED_MODEL_PATH = os.path.join(MODELS_DIR, "multilingual-e5-base-q4_k_m.gguf")
CHAT_MODEL_PATH = os.path.join(MODELS_DIR, "Qwen2.5-3B-Instruct-Q4_K_M.gguf")


class ChatRequest(BaseModel):
    query: str
    session_id: Optional[str] = "default"


class ChatResponse(BaseModel):
    answer: str
    sources: List[str]


class IngestRequest(BaseModel):
    text: str
    title: str
    doc_id: str


class Chatbot:
    def __init__(self):
        # Initialize FastAPI
        self.app = FastAPI()
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        print("Loading AI Models...")
        # Load local models
        self.embed_model = Llama(
            model_path=EMBED_MODEL_PATH,
            embedding=True,
            n_ctx=512,
            n_threads=os.cpu_count() or 4,
            n_gpu_layers=-1,  # use all available gpu layers
            verbose=False,
        )
        self.llm = Llama(
            model_path=CHAT_MODEL_PATH,
            n_ctx=4096,
            n_threads=os.cpu_count() or 4,
            n_gpu_layers=-1,  # use all available gpu layers
            verbose=False,
        )

        # Setup chromaDB (vector storage)
        print("Cleaning up database context...")
        if os.path.exists(CHROMA_DB_DIR):
            try:
                shutil.rmtree(CHROMA_DB_DIR)
            except Exception as e:
                print(f"Startup cleanup failed: {e}")

        self.chroma_client = chromadb.PersistentClient(
            path=CHROMA_DB_DIR, settings=Settings(allow_reset=True)
        )
        self.collection: Any = None
        self.clear_db()

        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=750, chunk_overlap=100, separators=["\n\n", ".", "।", "?", "!"]
        )

        self._register_routes()

    def clear_db(self):
        try:
            self.chroma_client.reset()
        except Exception as e:
            print(f"Reset failed: {e}. Falling back to delete_collection.")
            try:
                self.chroma_client.delete_collection("articles_demo")
            except Exception:
                pass
        self.collection = self.chroma_client.get_or_create_collection("articles_demo")

    def _register_routes(self):
        @self.app.post("/ingest")
        async def ingest(request: IngestRequest):
            return {
                "status": "success",
                "chunks_ingested": self.ingest_text(
                    request.text, request.title, request.doc_id
                ),
            }

        @self.app.post("/ingest-file")
        async def ingest_file(
            file: UploadFile = File(...),
            title: str = Form(...),
            doc_id: str = Form(...),
        ):
            file_bytes = await file.read()
            filename = file.filename or "unknown"
            file_ext = filename.split(".")[-1].lower()
            content = self.extract_text(file_bytes, file_ext)
            return {
                "status": "success",
                "chunks_ingested": self.ingest_text(
                    content, title, doc_id, {"source": filename}
                ),
            }

        @self.app.post("/chat")
        async def chat(request: ChatRequest):
            answer, sources = self.generate_answer(request.query)
            return ChatResponse(answer=answer, sources=sources)

        @self.app.post("/clear")
        async def clear():
            self.clear_db()
            return {"status": "success", "message": "Database cleared"}

        @self.app.get("/health")
        async def health():
            return {"status": "ok"}

    # RAG implementation
    def get_embedding(self, text: str) -> Any:
        res = self.embed_model.create_embedding(f"search_document: {text}")
        return res["data"][0]["embedding"]

    def extract_text(self, file_bytes: bytes, ext: str) -> str:
        if ext == "pdf":
            with fitz.open(stream=file_bytes, filetype="pdf") as doc:
                return "".join(str(page.get_text()) for page in doc)
        if ext == "docx":
            return "\n".join(
                p.text for p in Document(io.BytesIO(file_bytes)).paragraphs
            )
        if ext == "html":
            return BeautifulSoup(file_bytes.decode("utf-8"), "html.parser").get_text(
                separator="\n", strip=True
            )
        if ext == "txt":
            return file_bytes.decode("utf-8")
        raise ValueError(f"Unsupported: {ext}")

    def ingest_text(
        self, text: str, title: str, doc_id: str, meta: Optional[dict] = None
    ):
        meta = meta or {}
        chunks = self.text_splitter.split_text(text)
        for i, chunk in enumerate(chunks):
            self.collection.add(
                ids=[f"{doc_id}_{i}"],
                embeddings=[self.get_embedding(chunk)],
                documents=[chunk],
                metadatas=[{"title": title, "doc_id": doc_id, **meta}],
            )
        return len(chunks)

    def generate_answer(self, query: str):
        try:
            # Check if there is anything in the collection
            if self.collection.count() == 0:
                return "Hhmph. You have not uploaded a document yet...", []

            results = self.collection.query(
                query_embeddings=[
                    list(map(float, self.get_embedding(f"search_query: {query}")))
                ],
                n_results=5,
            )
            documents = results.get("documents")
            context = ""
            if documents and documents[0]:
                context = "\n\n".join(str(d) for d in documents[0])

            # If no context is found
            if not context.strip():
                return (
                    "There is not enough context provided in the uploaded documents.",
                    [],
                )

            metadatas = results.get("metadatas")
            sources: List[str] = []
            if metadatas and metadatas[0]:
                sources = list(
                    set(str(m.get("title", "Unknown")) for m in metadatas[0] if m)
                )
            prompt = f"""
You are a helpful AI assistant.
Answer strictly based on the context below. Do not use words like from the context.
If the context does not contain enough information, respond with: Not enough information in the provided documents.

Context: {context.strip()}
Question: {query}

Answer:
"""
            response = self.llm(
                prompt,
                max_tokens=512,
                temperature=0.1,
            )
            if isinstance(response, dict):
                answer = str(response["choices"][0]["text"]).strip()
                # Clear sources if not enough information
                if "not enough information" in answer.lower():
                    sources = []
            else:
                answer = "Error generating response from AI model."
            return answer, sources
        except Exception as e:
            print(f"Error in generate_answer: {e}")
            return f"An error occurred during processing: {str(e)}", []


# Shut down backend on crash or window close
def monitor_parent():
    ppid = os.getppid()
    while True:
        if os.getppid() != ppid:
            # Final cleanup on exit
            if os.path.exists(CHROMA_DB_DIR):
                try:
                    shutil.rmtree(CHROMA_DB_DIR)
                except FileNotFoundError:
                    pass
            os._exit(0)
        time.sleep(2)


if __name__ == "__main__":
    threading.Thread(target=monitor_parent, daemon=True).start()
    bot = Chatbot()
    app = bot.app
    uvicorn.run(app, host="127.0.0.1", port=8000)
