from pathlib import Path

from huggingface_hub import hf_hub_download


def download_models():
    # Set directory for models
    models_dir = Path(__file__).resolve().parent.parent / "models"
    models_dir.mkdir(parents=True, exist_ok=True)

    models = [
        {
            "repo": "dinab/multilingual-e5-base-Q4_K_M-GGUF",
            "file": "multilingual-e5-base-q4_k_m.gguf",  # embedding model
            "size": "219 MB",
        },
        {
            "repo": "bartowski/Qwen2.5-3B-Instruct-GGUF",
            "file": "Qwen2.5-3B-Instruct-Q4_K_M.gguf",  # chat model
            "size": "1.79 GB",
        },
    ]

    for m in models:
        target = models_dir / m["file"]
        if target.exists():
            print(f"{m['file']} already exists.")
            continue

        try:
            hf_hub_download(
                repo_id=m["repo"],
                filename=m["file"],
                local_dir=str(models_dir),
            )
            print(f"{m['file']} ({m['size']}) downloaded\n")
        except Exception as e:
            print(f"Failed to download {m['file']}: {e}")

    print("All downloads finished!")


if __name__ == "__main__":
    download_models()
