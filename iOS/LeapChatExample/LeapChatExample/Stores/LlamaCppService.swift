import Foundation
import SwiftUI

/// Direct llama.cpp inference service using dlsym to access the C API
/// from the already-loaded inference_engine_llamacpp_backend framework.
/// Used for GGUF models that aren't in the LeapSDK model registry.
@Observable
class LlamaCppService {
    var isLoaded = false

    @ObservationIgnored private var model: OpaquePointer?
    @ObservationIgnored private var ctx: OpaquePointer?
    @ObservationIgnored private var sampler: OpaquePointer?

    // MARK: - dlsym function pointers

    private typealias BackendInitFn = @convention(c) () -> Void
    private typealias BackendFreeFn = @convention(c) () -> Void
    private typealias ModelDefaultParamsFn = @convention(c) () -> LlamaModelParams
    private typealias LoadModelFn = @convention(c) (UnsafePointer<CChar>, LlamaModelParams) -> OpaquePointer?
    private typealias ContextDefaultParamsFn = @convention(c) () -> LlamaContextParams
    private typealias NewContextFn = @convention(c) (OpaquePointer, LlamaContextParams) -> OpaquePointer?
    private typealias FreeFn = @convention(c) (OpaquePointer) -> Void
    private typealias FreeModelFn = @convention(c) (OpaquePointer) -> Void
    private typealias TokenizeFn = @convention(c) (OpaquePointer, UnsafePointer<CChar>, Int32, UnsafeMutablePointer<Int32>, Int32, Bool, Bool) -> Int32
    private typealias DecodeFn = @convention(c) (OpaquePointer, LlamaBatch) -> Int32
    private typealias TokenToFn = @convention(c) (OpaquePointer, Int32, UnsafeMutablePointer<CChar>, Int32, Int32, Bool) -> Int32
    private typealias TokenEosFn = @convention(c) (OpaquePointer) -> Int32
    private typealias NVocabFn = @convention(c) (OpaquePointer) -> Int32
    private typealias SamplerChainInitFn = @convention(c) (LlamaSamplerChainParams) -> OpaquePointer
    private typealias SamplerChainDefaultFn = @convention(c) () -> LlamaSamplerChainParams
    private typealias SamplerChainAddFn = @convention(c) (OpaquePointer, OpaquePointer) -> Void
    private typealias SamplerInitTempFn = @convention(c) (Float) -> OpaquePointer
    private typealias SamplerInitDistFn = @convention(c) (UInt32) -> OpaquePointer
    private typealias SamplerInitGreedyFn = @convention(c) () -> OpaquePointer
    private typealias SamplerSampleFn = @convention(c) (OpaquePointer, OpaquePointer, Int32) -> Int32
    private typealias SamplerAcceptFn = @convention(c) (OpaquePointer, Int32) -> Void
    private typealias SamplerFreeFn = @convention(c) (OpaquePointer) -> Void
    private typealias BatchInitFn = @convention(c) (Int32, Int32, Int32) -> LlamaBatch
    private typealias BatchFreeFn = @convention(c) (LlamaBatch) -> Void
    private typealias GetLogitsFn = @convention(c) (OpaquePointer) -> UnsafeMutablePointer<Float>?

    // Minimal C struct layouts matching llama.cpp
    struct LlamaModelParams {
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    struct LlamaContextParams {
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    struct LlamaSamplerChainParams {
        var no_perf: Bool = false
    }

    struct LlamaBatch {
        var n_tokens: Int32 = 0
        var token: UnsafeMutablePointer<Int32>?
        var embd: UnsafeMutablePointer<Float>?
        var pos: UnsafeMutablePointer<Int32>?
        var n_seq_id: UnsafeMutablePointer<Int32>?
        var seq_id: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>?
        var logits: UnsafeMutablePointer<Int8>?
    }

    private func sym<T>(_ name: String) -> T? {
        guard let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }

    // MARK: - Load Model

    func load(ggufPath: String) throws {
        guard let backendInit: BackendInitFn = sym("llama_backend_init"),
              let modelDefaultParams: ModelDefaultParamsFn = sym("llama_model_default_params"),
              let loadModel: LoadModelFn = sym("llama_load_model_from_file"),
              let ctxDefaultParams: ContextDefaultParamsFn = sym("llama_context_default_params"),
              let newContext: NewContextFn = sym("llama_new_context_with_model"),
              let chainDefault: SamplerChainDefaultFn = sym("llama_sampler_chain_default_params"),
              let chainInit: SamplerChainInitFn = sym("llama_sampler_chain_init"),
              let chainAdd: SamplerChainAddFn = sym("llama_sampler_chain_add"),
              let initGreedy: SamplerInitGreedyFn = sym("llama_sampler_init_greedy")
        else {
            throw LlamaCppError.symbolsNotFound
        }

        backendInit()

        let modelParams = modelDefaultParams()
        guard let m = ggufPath.withCString({ loadModel($0, modelParams) }) else {
            throw LlamaCppError.failedToLoadModel
        }
        model = m

        var ctxParams = ctxDefaultParams()
        // Set n_ctx to 4096 (first 4 bytes in the struct)
        withUnsafeMutableBytes(of: &ctxParams.data) { buf in
            buf.storeBytes(of: UInt32(4096), as: UInt32.self)
        }

        guard let c = newContext(m, ctxParams) else {
            throw LlamaCppError.failedToCreateContext
        }
        ctx = c

        let sparams = chainDefault()
        let s = chainInit(sparams)
        chainAdd(s, initGreedy())
        sampler = s

        isLoaded = true
    }

    // MARK: - Generate

    func generate(prompt: String, maxTokens: Int = 512) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task.detached { [weak self] in
                guard let self, let model = self.model, let ctx = self.ctx, let sampler = self.sampler else {
                    continuation.yield("Error: Model not loaded")
                    continuation.finish()
                    return
                }

                guard let tokenize: TokenizeFn = self.sym("llama_tokenize"),
                      let decode: DecodeFn = self.sym("llama_decode"),
                      let batchInit: BatchInitFn = self.sym("llama_batch_init"),
                      let batchFree: BatchFreeFn = self.sym("llama_batch_free"),
                      let samplerSample: SamplerSampleFn = self.sym("llama_sampler_sample"),
                      let samplerAccept: SamplerAcceptFn = self.sym("llama_sampler_accept"),
                      let tokenToPiece: TokenToFn = self.sym("llama_token_to_piece"),
                      let tokenEos: TokenEosFn = self.sym("llama_token_eos")
                else {
                    continuation.yield("Error: Missing llama.cpp symbols")
                    continuation.finish()
                    return
                }

                // Tokenize prompt
                let maxToks: Int32 = 2048
                var tokens = [Int32](repeating: 0, count: Int(maxToks))
                let nTokens = prompt.withCString { cstr in
                    tokenize(model, cstr, Int32(prompt.utf8.count), &tokens, maxToks, true, false)
                }

                guard nTokens > 0 else {
                    continuation.yield("Error: Tokenization failed")
                    continuation.finish()
                    return
                }

                // Create batch and fill with prompt tokens
                var batch = batchInit(2048, 0, 1)
                for i in 0..<nTokens {
                    let seqId: Int32 = 0
                    batch.token?[Int(i)] = tokens[Int(i)]
                    batch.pos?[Int(i)] = i
                    batch.n_seq_id?[Int(i)] = 1
                    batch.seq_id?[Int(i)]?.pointee = seqId
                    batch.logits?[Int(i)] = (i == nTokens - 1) ? 1 : 0
                }
                batch.n_tokens = nTokens

                // Decode prompt
                let promptResult = decode(ctx, batch)
                guard promptResult == 0 else {
                    continuation.yield("Error: Prompt decode failed")
                    batchFree(batch)
                    continuation.finish()
                    return
                }

                // Generate tokens
                let eosToken = tokenEos(model)
                var nDecoded: Int32 = 0
                var buf = [CChar](repeating: 0, count: 256)

                for _ in 0..<maxTokens {
                    let newToken = samplerSample(sampler, ctx, batch.n_tokens - 1)
                    samplerAccept(sampler, newToken)

                    if newToken == eosToken { break }

                    let len = tokenToPiece(model, newToken, &buf, Int32(buf.count), 0, false)
                    if len > 0 {
                        let piece = String(cString: buf.prefix(Int(len)) + [0])
                        continuation.yield(piece)
                    }

                    // Prepare next batch
                    batch.n_tokens = 1
                    batch.token?[0] = newToken
                    batch.pos?[0] = nTokens + nDecoded
                    batch.n_seq_id?[0] = 1
                    let seqId: Int32 = 0
                    batch.seq_id?[0]?.pointee = seqId
                    batch.logits?[0] = 1

                    let result = decode(ctx, batch)
                    if result != 0 { break }

                    nDecoded += 1
                }

                batchFree(batch)
                continuation.finish()
            }
        }
    }

    // MARK: - Cleanup

    func unload() {
        if let s = sampler {
            if let free: SamplerFreeFn = sym("llama_sampler_free") { free(s) }
        }
        if let c = ctx {
            if let free: FreeFn = sym("llama_free") { free(c) }
        }
        if let m = model {
            if let free: FreeModelFn = sym("llama_free_model") { free(m) }
        }
        sampler = nil
        ctx = nil
        model = nil
        isLoaded = false
    }

    deinit {
        unload()
    }

    enum LlamaCppError: LocalizedError {
        case symbolsNotFound
        case failedToLoadModel
        case failedToCreateContext

        var errorDescription: String? {
            switch self {
            case .symbolsNotFound: return "llama.cpp symbols not found in loaded frameworks"
            case .failedToLoadModel: return "Failed to load GGUF model file"
            case .failedToCreateContext: return "Failed to create inference context"
            }
        }
    }
}
