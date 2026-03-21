import Foundation

enum ModelCategory: String, CaseIterable, Identifiable {
    case chat = "Chat models"
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

    init(
        id: String, name: String, provider: String, parameterCount: String,
        category: ModelCategory, description: String,
        quantizations: [QuantizationOption], huggingFaceRepo: String? = nil,
        isMLX: Bool = false, useDirectLlamaCpp: Bool = false
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
        ModelDefinition(
            id: "Qwen3-0.6B", name: "Qwen3-0.6B", provider: "Qwen",
            parameterCount: "0.6B", category: .chat,
            description:
                "Compact Qwen3 model for lightweight on-device chat applications.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "400 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "420 MB"),
                QuantizationOption(name: "Q8_0", fileSize: "600 MB"),
            ],
            huggingFaceRepo: "Qwen/Qwen3-0.6B-GGUF"),
        ModelDefinition(
            id: "Qwen3-1.7B", name: "Qwen3-1.7B", provider: "Qwen",
            parameterCount: "1.7B", category: .chat,
            description:
                "Mid-size Qwen3 model with strong multilingual capabilities.",
            quantizations: [
                QuantizationOption(name: "Q4_0", fileSize: "950 MB"),
                QuantizationOption(name: "Q4_K_M", fileSize: "1.0 GB"),
                QuantizationOption(name: "Q8_0", fileSize: "1.7 GB"),
            ],
            huggingFaceRepo: "Qwen/Qwen3-1.7B-GGUF"),

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
            id: "GLM-OCR", name: "GLM-OCR", provider: "ZAI",
            parameterCount: "0.9B", category: .ocr,
            description:
                "GLM-OCR is a multimodal OCR model for complex document understanding, ranked #1 on OmniDocBench. Features a CogViT visual encoder and GLM-0.5B language decoder, optimized for tables, code-heavy documents, and real-world OCR scenarios with only 0.9B parameters.",
            quantizations: [
                QuantizationOption(
                    name: "Q8_0", fileSize: "950 MB",
                    downloadURL: "https://huggingface.co/ggml-org/GLM-OCR-GGUF/resolve/main/GLM-OCR-Q8_0.gguf"),
                QuantizationOption(
                    name: "f16", fileSize: "1.79 GB",
                    downloadURL: "https://huggingface.co/ggml-org/GLM-OCR-GGUF/resolve/main/GLM-OCR-f16.gguf"),
            ],
            huggingFaceRepo: "ggml-org/GLM-OCR-GGUF"),
        // GLM-OCR via direct llama.cpp — uses bundled inference engine, bypasses LeapSDK registry
        ModelDefinition(
            id: "GLM-OCR-Direct", name: "GLM-OCR", provider: "ZAI",
            parameterCount: "0.9B", category: .ocr,
            description:
                "GLM-OCR loaded directly via llama.cpp. Multimodal OCR model for complex document understanding, ranked #1 on OmniDocBench. Download from HuggingFace and run inference using the bundled llama.cpp engine.",
            quantizations: [
                QuantizationOption(
                    name: "Q8_0", fileSize: "950 MB",
                    downloadURL: "https://huggingface.co/ggml-org/GLM-OCR-GGUF/resolve/main/GLM-OCR-Q8_0.gguf"),
            ],
            huggingFaceRepo: "ggml-org/GLM-OCR-GGUF",
            useDirectLlamaCpp: true),
    ]

    static func models(for category: ModelCategory) -> [ModelDefinition] {
        allModels.filter { $0.category == category }
    }
}
