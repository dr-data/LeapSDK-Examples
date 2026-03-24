import Foundation

enum ModelCategory: String, CaseIterable, Identifiable {
    case chat = "Chat models"
    case math = "Math Models"
    case rag = "RAG Models"
    case translate = "Translate Models"
    case extract = "Extract Models"
    case audio = "Audio Models"
    case vision = "Vision Models"
    case ocr = "OCR Models"

    var id: String { rawValue }
}

struct QuantizationOption: Identifiable, Hashable {
    let name: String
    let fileSize: String
    let downloadURL: String?

    var id: String { name }

    init(name: String, fileSize: String, downloadURL: String? = nil) {
        self.name = name
        self.fileSize = fileSize
        self.downloadURL = downloadURL
    }
}

struct ModelDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let parameterCount: String
    let category: ModelCategory
    let description: String
    let quantizations: [QuantizationOption]
    let huggingFaceRepo: String?
    let isMLX: Bool
    let useDirectLlamaCpp: Bool
    let isGLMOCR: Bool
    let isPaddleOCR: Bool
    let paddleOCRBackend: String?  // "onnx" or "coreml"
    let isHuggingFaceOnly: Bool    // download-only from HuggingFace Hub (no Leap.load)

    init(
        id: String, name: String, provider: String, parameterCount: String,
        category: ModelCategory, description: String,
        quantizations: [QuantizationOption], huggingFaceRepo: String? = nil,
        isMLX: Bool = false, useDirectLlamaCpp: Bool = false,
        isGLMOCR: Bool = false,
        isPaddleOCR: Bool = false, paddleOCRBackend: String? = nil,
        isHuggingFaceOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.parameterCount = parameterCount
        self.category = category
        self.description = description
        self.quantizations = quantizations
        self.huggingFaceRepo = huggingFaceRepo
        self.isMLX = isMLX
        self.useDirectLlamaCpp = useDirectLlamaCpp
        self.isGLMOCR = isGLMOCR
        self.isPaddleOCR = isPaddleOCR
        self.paddleOCRBackend = paddleOCRBackend
        self.isHuggingFaceOnly = isHuggingFaceOnly
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelDefinition, rhs: ModelDefinition) -> Bool {
        lhs.id == rhs.id
    }

    func downloadURL(for quantization: QuantizationOption) -> URL? {
        if let url = quantization.downloadURL {
            return URL(string: url)
        }
        guard let repo = huggingFaceRepo else { return nil }
        let fileName = "\(id)-\(quantization.name).gguf"
        return URL(string: "https://huggingface.co/\(repo)/resolve/main/\(fileName)")
    }
}

enum ModelCatalog {
    static let allModels: [ModelDefinition] = [
        // Chat models
        ModelDefinition(
            id: "LFM2-2.6B", name: "LFM2-2.6B", provider: "LiquidAI",
            parameterCount: "2.6B", category: .chat,
            description:
                "LFM2 is a hybrid-architecture class of Liquid Foundation Models (LFMs) that sets a new standard in quality, speed, and memory-efficient deployment. LFM2 is specifically designed to provide the fastest on-device gen-AI experience across the industry.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "1.4 GB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "1.5 GB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "1.7 GB"),
                QuantizationOption(name: "Q8_0", fileSize: "2.6 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-2.6B-GGUF"),
        ModelDefinition(
            id: "LFM2-2.6B-Exp", name: "LFM2-2.6B-Exp", provider: "LiquidAI",
            parameterCount: "2.6B", category: .chat,
            description:
                "Experimental variant of LFM2-2.6B with enhanced capabilities for advanced use cases.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "1.4 GB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "1.5 GB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "1.7 GB"),
                QuantizationOption(name: "Q8_0", fileSize: "2.6 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-2.6B-Exp-GGUF"),
        ModelDefinition(
            id: "LFM2-350M", name: "LFM2-350M", provider: "LiquidAI",
            parameterCount: "350M", category: .chat,
            description:
                "Compact LFM2 model optimized for fast inference on resource-constrained devices.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "209 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "220 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "250 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "350 MB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-350M-GGUF"),
        ModelDefinition(
            id: "LFM2-700M", name: "LFM2-700M", provider: "LiquidAI",
            parameterCount: "700M", category: .chat,
            description:
                "Mid-size LFM2 model balancing quality and speed for on-device inference.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "400 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "420 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "480 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "700 MB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-700M-GGUF"),
        ModelDefinition(
            id: "LFM2.5-1.2B-Instruct", name: "LFM2.5-1.2B-Instruct", provider: "LiquidAI",
            parameterCount: "1.2B", category: .chat,
            description:
                "Instruction-tuned LFM2.5 model optimized for following user instructions with high accuracy.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "663.5 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "697 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "804.3 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.2 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2.5-1.2B-Instruct-GGUF"),
        ModelDefinition(
            id: "LFM2.5-1.2B-JP", name: "LFM2.5-1.2B-JP", provider: "LiquidAI",
            parameterCount: "1.2B", category: .chat,
            description:
                "Japanese-optimized LFM2.5 model for high-quality Japanese language generation.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "663.5 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "697 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "804.3 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.2 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2.5-1.2B-JP-GGUF"),
        ModelDefinition(
            id: "LFM2.5-1.2B-Thinking", name: "LFM2.5-1.2B-Thinking", provider: "LiquidAI",
            parameterCount: "1.2B", category: .chat,
            description:
                "LFM2.5 model with extended thinking capabilities for complex reasoning tasks.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "663.5 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "697 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "804.3 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.2 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2.5-1.2B-Thinking-GGUF"),

        // Qwen models (available on LEAP platform via Leap.load() — Q8_0 only)
        ModelDefinition(
            id: "Qwen3-0.6B", name: "Qwen3-0.6B", provider: "Qwen",
            parameterCount: "0.6B", category: .chat,
            description:
                "Compact Qwen3 model for lightweight on-device chat via LEAP platform.",
            quantizations: [
                QuantizationOption(name: "Q8_0", fileSize: "600 MB"),
            ],
            huggingFaceRepo: "Qwen/Qwen3-0.6B-GGUF"),
        ModelDefinition(
            id: "Qwen3-1.7B", name: "Qwen3-1.7B", provider: "Qwen",
            parameterCount: "1.7B", category: .chat,
            description:
                "Mid-size Qwen3 model with strong multilingual capabilities via LEAP platform.",
            quantizations: [
                QuantizationOption(name: "Q8_0", fileSize: "1.7 GB"),
            ],
            huggingFaceRepo: "Qwen/Qwen3-1.7B-GGUF"),

        // Math models
        ModelDefinition(
            id: "LFM2-350M-Math", name: "LFM2-350M-Math", provider: "LiquidAI",
            parameterCount: "350M", category: .math,
            description:
                "Math reasoning model based on LFM2-350M with 32K context window. Optimized for mathematical problem solving, step-by-step reasoning, and edge deployment.",
            quantizations: [
                QuantizationOption(name: "Q4_K_M", fileSize: "220 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "350 MB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-350M-Math-GGUF"),

        // RAG models
        ModelDefinition(
            id: "LFM2-1.2B-RAG", name: "LFM2-1.2B-RAG", provider: "LiquidAI",
            parameterCount: "1.2B", category: .rag,
            description:
                "RAG-optimized model based on LFM2-1.2B with 32K context window. Designed for retrieval-augmented generation with document extraction, supporting XML-tagged document inputs.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "663.5 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "697 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.2 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-1.2B-RAG-GGUF"),

        // Translate models
        ModelDefinition(
            id: "LFM2-350M-ENJP-MT", name: "LFM2-350M-ENJP-MT", provider: "LiquidAI",
            parameterCount: "350M", category: .translate,
            description:
                "English-Japanese machine translation model based on LFM2-350M.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "209 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "350 MB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-350M-ENJP-MT-GGUF"),

        // Extract models
        ModelDefinition(
            id: "LFM2-1.2B-Extract", name: "LFM2-1.2B-Extract", provider: "LiquidAI",
            parameterCount: "1.2B", category: .extract,
            description:
                "Based on the LFM2-1.2B model, this checkpoint has been finetuned for high performance at use cases involving structured data extraction from unstructured input content.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "663.5 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "697 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "804.3 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.2 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-1.2B-Extract-GGUF"),
        ModelDefinition(
            id: "LFM2-350M-Extract", name: "LFM2-350M-Extract", provider: "LiquidAI",
            parameterCount: "350M", category: .extract,
            description:
                "Compact extraction model based on LFM2-350M for structured data extraction.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "209 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "350 MB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-350M-Extract-GGUF"),

        // Audio models
        ModelDefinition(
            id: "LFM2.5-Audio-1.5B", name: "LFM2.5-Audio-1.5B", provider: "LiquidAI",
            parameterCount: "1.5B", category: .audio,
            description:
                "Speech-to-speech model supporting audio input and output for conversational AI.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "900 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.5 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2.5-Audio-1.5B-GGUF"),

        // Vision models
        ModelDefinition(
            id: "LFM2-VL-3B", name: "LFM2-VL-3B", provider: "LiquidAI",
            parameterCount: "3B", category: .vision,
            description:
                "Large vision-language model for detailed image analysis and multimodal understanding.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "1.7 GB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "1.8 GB"),
                QuantizationOption(name: "Q8_0", fileSize: "3.0 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-VL-3B-GGUF"),
        ModelDefinition(
            id: "LFM2-VL-450M", name: "LFM2-VL-450M", provider: "LiquidAI",
            parameterCount: "450M", category: .vision,
            description:
                "Compact vision-language model for efficient on-device image understanding.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "270 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "285 MB"),
                QuantizationOption(name: "Q5_K_M", fileSize: "320 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "450 MB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2-VL-450M-GGUF"),
        ModelDefinition(
            id: "LFM2.5-VL-1.6B", name: "LFM2.5-VL-1.6B", provider: "LiquidAI",
            parameterCount: "1.6B", category: .vision,
            description:
                "Vision-enabled multimodal model for image analysis and visual question answering.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "1.0 GB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "1.05 GB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.6 GB"),
            ],
            huggingFaceRepo: "LiquidAI/LFM2.5-VL-1.6B-GGUF"),

        // OCR models
        ModelDefinition(
            id: "GLM-OCR", name: "GLM-OCR (MLX)", provider: "ZAI",
            parameterCount: "0.9B", category: .ocr,
            description:
                "GLM-OCR via MLX Swift. 131K context window. Ranked #1 on OmniDocBench. CogViT visual encoder + GLM-0.5B language decoder. Optimized for tables, code-heavy documents, and real-world OCR.",
            quantizations: [
                QuantizationOption(name: "safetensors", fileSize: "~1.8 GB"),
            ],
            huggingFaceRepo: "zai-org/GLM-OCR",
            isGLMOCR: true),
        ModelDefinition(
            id: "GLM-OCR-ONNX", name: "GLM-OCR (ONNX)", provider: "ZAI",
            parameterCount: "0.9B", category: .ocr,
            description:
                "GLM-OCR via ONNX Runtime. 131K context window. Quantized for efficient on-device inference. Downloads from HuggingFace.",
            quantizations: [
                QuantizationOption(name: "quant", fileSize: "~900 MB"),
            ],
            huggingFaceRepo: "Ji-Ha/glm-ocr-onnx",
            isHuggingFaceOnly: true),
        ModelDefinition(
            id: "PP-OCRv5-Mobile-ONNX", name: "PP-OCRv5 Mobile (ONNX)", provider: "PaddlePaddle",
            parameterCount: "~4M", category: .ocr,
            description:
                "PP-OCRv5 server detector + PP-OCRv5 English recognizer. ONNX Runtime with CoreML acceleration. ~96MB total.",
            quantizations: [
                QuantizationOption(name: "fp32", fileSize: "~96 MB"),
            ],
            huggingFaceRepo: "monkt/paddleocr-onnx",
            isPaddleOCR: true, paddleOCRBackend: "onnx"),
        ModelDefinition(
            id: "LightOnOCR-2-1B", name: "LightOnOCR-2-1B", provider: "LightOn",
            parameterCount: "1B", category: .ocr,
            description:
                "End-to-end VLM-based OCR by LightOn AI. 83%+ accuracy on OlmOCR-Bench, supports 11 languages. Attach an image to extract text.",
            quantizations: [
                QuantizationOption(name: "Q4_K_M", fileSize: "~700 MB"),
            ],
            huggingFaceRepo: "lightonai/LightOnOCR-2-1B-GGUF",
            useDirectLlamaCpp: true),
        ModelDefinition(
            id: "Apple-Vision-OCR", name: "Apple Vision OCR", provider: "Apple",
            parameterCount: "Built-in", category: .ocr,
            description:
                "Built-in iOS text recognition using Apple Vision framework. No download required. Supports English, Chinese, Japanese, Korean, and more.",
            quantizations: [
                QuantizationOption(name: "built-in", fileSize: "0 MB"),
            ]),
    ]

    static func models(for category: ModelCategory) -> [ModelDefinition] {
        allModels.filter { $0.category == category }
    }
}
