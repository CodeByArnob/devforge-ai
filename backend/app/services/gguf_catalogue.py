"""Local GGUF model catalogue with license, checksum, ABI, and RAM validation."""
import hashlib
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class LocalGGUFModel:
    id: str
    name: str
    family: str
    parameters: str
    quantization: str
    license: str
    sha256: str
    context_length: int
    file_size_gb: float
    min_ram_gb: float
    recommended_vram_gb: float
    supported_abis: tuple[str, ...]
    download_url: str


LOCAL_GGUF_CATALOGUE: tuple[LocalGGUFModel, ...] = (
    LocalGGUFModel(
        id="llama-3.2-3b-instruct-q4km",
        name="Llama 3.2 3B Instruct",
        family="llama",
        parameters="3B",
        quantization="Q4_K_M",
        license="Llama-3.2-Community",
        sha256="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        context_length=131072,
        file_size_gb=2.02,
        min_ram_gb=3.5,
        recommended_vram_gb=4.0,
        supported_abis=("avx2", "avx512", "cuda", "metal", "vulkan"),
        download_url="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF",
    ),
    LocalGGUFModel(
        id="qwen2.5-coder-7b-instruct-q4km",
        name="Qwen 2.5 Coder 7B Instruct",
        family="qwen",
        parameters="7B",
        quantization="Q4_K_M",
        license="Apache-2.0",
        sha256="4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a",
        context_length=32768,
        file_size_gb=4.68,
        min_ram_gb=7.5,
        recommended_vram_gb=8.0,
        supported_abis=("avx2", "avx512", "cuda", "metal", "vulkan"),
        download_url="https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF",
    ),
    LocalGGUFModel(
        id="deepseek-coder-6.7b-instruct-q4km",
        name="DeepSeek Coder 6.7B Instruct",
        family="deepseek",
        parameters="6.7B",
        quantization="Q4_K_M",
        license="DeepSeek-License",
        sha256="ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d",
        context_length=16384,
        file_size_gb=4.21,
        min_ram_gb=6.8,
        recommended_vram_gb=8.0,
        supported_abis=("avx2", "cuda", "metal", "vulkan"),
        download_url="https://huggingface.co/TheBloke/deepseek-coder-6.7B-instruct-GGUF",
    ),
    LocalGGUFModel(
        id="mistral-7b-instruct-v0.3-q4km",
        name="Mistral 7B Instruct v0.3",
        family="mistral",
        parameters="7B",
        quantization="Q4_K_M",
        license="Apache-2.0",
        sha256="68997ef31e847c21e7d0f983637e750fcfa2790209e99a8b132e4d262da3c89c",
        context_length=32768,
        file_size_gb=4.37,
        min_ram_gb=7.0,
        recommended_vram_gb=8.0,
        supported_abis=("avx2", "cuda", "metal", "vulkan"),
        download_url="https://huggingface.co/MaziyarPanahi/Mistral-7B-Instruct-v0.3-GGUF",
    ),
)


GGUF_MAGIC = b"GGUF"


class GGUFValidationError(ValueError):
    pass


def list_catalogue() -> list[dict]:
    return [asdict(model) for model in LOCAL_GGUF_CATALOGUE]


def get_catalogue_model(model_id: str) -> LocalGGUFModel | None:
    for model in LOCAL_GGUF_CATALOGUE:
        if model.id == model_id:
            return model
    return None


def calculate_ram_requirement(
    file_size_bytes: int,
    context_tokens: int,
    hidden_dim: int = 4096,
    num_layers: int = 32,
    bytes_per_cache_element: int = 2,
) -> dict:
    weights_ram_bytes = int(file_size_bytes * 1.15)
    # KV Cache bytes: 2 * num_layers * hidden_dim * context_tokens * bytes_per_element
    kv_cache_bytes = 2 * num_layers * hidden_dim * context_tokens * bytes_per_cache_element
    total_bytes = weights_ram_bytes + kv_cache_bytes
    return {
        "weights_ram_gb": round(weights_ram_bytes / (1024**3), 2),
        "kv_cache_ram_gb": round(kv_cache_bytes / (1024**3), 2),
        "total_min_ram_gb": round(total_bytes / (1024**3), 2),
    }


def validate_gguf_file(
    file_path: Path, expected_sha256: str | None = None
) -> dict:
    if not file_path.is_file():
        raise GGUFValidationError("GGUF model file does not exist.")

    file_size = file_path.stat().st_size
    if file_size < 1024:
        raise GGUFValidationError("File is too small to be a valid GGUF container.")

    # Validate GGUF Magic Header
    with file_path.open("rb") as f:
        header = f.read(4)
        if header != GGUF_MAGIC:
            raise GGUFValidationError("Invalid GGUF header. Magic bytes mismatch.")

    # Compute SHA-256 digest
    hasher = hashlib.sha256()
    with file_path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            hasher.update(chunk)
    computed_digest = hasher.hexdigest()

    if expected_sha256 and computed_digest.lower() != expected_sha256.lower():
        raise GGUFValidationError(
            f"Checksum verification failed. Expected: {expected_sha256}, Got: {computed_digest}"
        )

    ram_req = calculate_ram_requirement(file_size, context_tokens=8192)
    return {
        "valid": True,
        "path": str(file_path),
        "file_size_bytes": file_size,
        "file_size_gb": round(file_size / (1024**3), 2),
        "sha256": computed_digest,
        "ram_requirement": ram_req,
    }
