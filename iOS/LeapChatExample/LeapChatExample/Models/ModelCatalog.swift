import Foundation

enum ModelCategory: String, CaseIterable, Identifiable {
  case chat = "Chat models"
  case translate = "Translate Models"
  case extract = "Extract Models"
  case audio = "Audio Models"
  case vision = "Vision Models"

  var id: String { rawValue }
}

struct QuantizationOption: Identifiable, Hashable {
  let name: String
  let fileSize: String

  var id: String { name }
}

struct ModelDefinition: Identifiable, Hashable {
  let id: String
  let name: String
  let provider: String
  let parameterCount: String
  let category: ModelCategory
  let description: String
  let quantizations: [QuantizationOption]

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: ModelDefinition, rhs: ModelDefinition) -> Bool {
    lhs.id == rhs.id
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
      ]),
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
      ]),
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
      ]),
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
      ]),
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
      ]),
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
      ]),
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
      ]),
    ModelDefinition(
      id: "Qwen3-0.6B", name: "Qwen3-0.6B", provider: "Qwen",
      parameterCount: "0.6B", category: .chat,
      description:
        "Compact Qwen3 model for lightweight on-device chat applications.",
      quantizations: [
        QuantizationOption(name: "Q4_0", fileSize: "400 MB"),
        QuantizationOption(name: "Q4_K_M", fileSize: "420 MB"),
        QuantizationOption(name: "Q8_0", fileSize: "600 MB"),
      ]),
    ModelDefinition(
      id: "Qwen3-1.7B", name: "Qwen3-1.7B", provider: "Qwen",
      parameterCount: "1.7B", category: .chat,
      description:
        "Mid-size Qwen3 model with strong multilingual capabilities.",
      quantizations: [
        QuantizationOption(name: "Q4_0", fileSize: "950 MB"),
        QuantizationOption(name: "Q4_K_M", fileSize: "1.0 GB"),
        QuantizationOption(name: "Q8_0", fileSize: "1.7 GB"),
      ]),

    // Translate models
    ModelDefinition(
      id: "LFM2-350M-ENJP-MT", name: "LFM2-350M-ENJP-MT", provider: "LiquidAI",
      parameterCount: "350M", category: .translate,
      description:
        "English-Japanese machine translation model based on LFM2-350M.",
      quantizations: [
        QuantizationOption(name: "Q4_0", fileSize: "209 MB"),
        QuantizationOption(name: "Q8_0", fileSize: "350 MB"),
      ]),

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
      ]),
    ModelDefinition(
      id: "LFM2-350M-Extract", name: "LFM2-350M-Extract", provider: "LiquidAI",
      parameterCount: "350M", category: .extract,
      description:
        "Compact extraction model based on LFM2-350M for structured data extraction.",
      quantizations: [
        QuantizationOption(name: "Q4_0", fileSize: "209 MB"),
        QuantizationOption(name: "Q8_0", fileSize: "350 MB"),
      ]),

    // Audio models
    ModelDefinition(
      id: "LFM2.5-Audio-1.5B", name: "LFM2.5-Audio-1.5B", provider: "LiquidAI",
      parameterCount: "1.5B", category: .audio,
      description:
        "Speech-to-speech model supporting audio input and output for conversational AI.",
      quantizations: [
        QuantizationOption(name: "Q4_0", fileSize: "900 MB"),
        QuantizationOption(name: "Q8_0", fileSize: "1.5 GB"),
      ]),

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
      ]),
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
      ]),
    ModelDefinition(
      id: "LFM2.5-VL-1.6B", name: "LFM2.5-VL-1.6B", provider: "LiquidAI",
      parameterCount: "1.6B", category: .vision,
      description:
        "Vision-enabled multimodal model for image analysis and visual question answering.",
      quantizations: [
        QuantizationOption(name: "Q4_0", fileSize: "1.0 GB"),
        QuantizationOption(name: "Q4_K_M", fileSize: "1.05 GB"),
        QuantizationOption(name: "Q8_0", fileSize: "1.6 GB"),
      ]),
  ]

  static func models(for category: ModelCategory) -> [ModelDefinition] {
    allModels.filter { $0.category == category }
  }
}
