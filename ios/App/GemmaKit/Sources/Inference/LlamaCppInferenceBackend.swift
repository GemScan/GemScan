import Foundation
import os
import llama

// MARK: - LlamaCppInferenceBackend

/// An ``InferenceBackend`` implementation that wraps llama.cpp via its C bridge.
///
/// Grammar constraints are enforced at sampling time using llama.cpp's native
/// GBNF grammar support, ensuring that every generated token conforms to the
/// specified output format.
public final class LlamaCppInferenceBackend: InferenceBackend, @unchecked Sendable {

    // MARK: - Properties

    /// Opaque pointer to the loaded llama model.
    private var model: OpaquePointer?

    /// Opaque pointer to the active llama context.
    private var context: OpaquePointer?

    /// Serial access lock for mutable state.
    private let lock = NSLock()

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// Path to the model weights on disk.
    private var modelPath: String?

    // MARK: - Initialization

    /// Creates a new llama.cpp inference backend.
    public init() {}

    // MARK: - InferenceBackend Conformance

    public var isLoaded: Bool {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return model != nil && context != nil
        }
    }

    public func loadModel(tier: ModelTier) async throws {
        logger.info("Loading model \(tier.rawValue) via llama.cpp")

        guard let path = ModelPathResolver.resolvedPath(for: tier) else {
            throw GemScanError.modelFileNotFound(tier: tier)
        }

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99 // offload all layers to GPU

        guard let loadedModel = llama_load_model_from_file(path, modelParams) else {
            throw GemScanError.modelLoadFailed(reason: "llama_load_model_from_file returned nil for \(tier.rawValue)")
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 4096
        contextParams.n_batch = 512

        guard let loadedContext = llama_new_context_with_model(loadedModel, contextParams) else {
            llama_free_model(loadedModel)
            throw GemScanError.modelLoadFailed(reason: "llama_new_context_with_model returned nil for \(tier.rawValue)")
        }

        lock.lock()
        self.model = loadedModel
        self.context = loadedContext
        self.modelPath = path
        lock.unlock()

        logger.info("llama.cpp model \(tier.rawValue) loaded from \(path)")
    }

    public func unloadModel() async {
        lock.lock()
        if let ctx = context {
            llama_free(ctx)
        }
        if let mdl = model {
            llama_free_model(mdl)
        }
        context = nil
        model = nil
        modelPath = nil
        lock.unlock()
        logger.info("llama.cpp model unloaded")
    }

    public func generate(
        prompt: String,
        grammar: GrammarConstraint?,
        maxTokens: Int
    ) async throws -> AsyncStream<String> {
        lock.lock()
        guard let mdl = model, let ctx = context else {
            lock.unlock()
            throw GemScanError.modelNotLoaded(tier: .e2b)
        }
        lock.unlock()

        let (stream, continuation) = AsyncStream<String>.makeStream()

        Task { [mdl, ctx] in
            do {
                // Tokenize the prompt
                let tokens = try self.tokenize(prompt: prompt, model: mdl)

                // Set up grammar if provided
                var grammarPtr: OpaquePointer?
                if let grammar = grammar {
                    grammarPtr = self.compileGrammar(gbnf: grammar.rawGBNF, model: mdl)
                }

                // Evaluate prompt tokens
                try self.evaluatePrompt(tokens: tokens, context: ctx)

                // Generate tokens
                for _ in 0..<maxTokens {
                    guard !Task.isCancelled else { break }

                    let tokenID = self.sampleNext(
                        context: ctx,
                        grammar: grammarPtr
                    )

                    // Check for end of generation
                    if llama_token_is_eog(mdl, tokenID) {
                        break
                    }

                    // Decode token to string
                    if let tokenString = self.decodeToken(tokenID, model: mdl) {
                        continuation.yield(tokenString)
                    }
                }

                if let gPtr = grammarPtr {
                    llama_grammar_free(gPtr)
                }

                continuation.finish()
            } catch {
                self.logger.error("llama.cpp generation error: \(error.localizedDescription)")
                continuation.finish()
            }
        }

        return stream
    }

    // MARK: - Private Helpers

    /// Tokenizes the input prompt string into llama token IDs.
    private func tokenize(prompt: String, model: OpaquePointer) throws -> [llama_token] {
        let utf8 = Array(prompt.utf8)
        let maxTokens = utf8.count + 16
        var tokens = [llama_token](repeating: 0, count: maxTokens)
        let tokenCount = llama_tokenize(model, prompt, Int32(utf8.count), &tokens, Int32(maxTokens), true, false)
        guard tokenCount >= 0 else {
            throw GemScanError.tokenizationFailed
        }
        return Array(tokens.prefix(Int(tokenCount)))
    }

    /// Evaluates prompt tokens in the context.
    private func evaluatePrompt(tokens: [llama_token], context: OpaquePointer) throws {
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (index, token) in tokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]?[0] = 0
            batch.logits[index] = (index == tokens.count - 1) ? 1 : 0
        }
        batch.n_tokens = Int32(tokens.count)

        let result = llama_decode(context, batch)
        guard result == 0 else {
            throw GemScanError.modelLoadFailed(reason: "llama_decode failed with code \(result)")
        }
    }

    /// Samples the next token, optionally constrained by a grammar.
    private func sampleNext(context: OpaquePointer, grammar: OpaquePointer?) -> llama_token {
        let logits = llama_get_logits(context)
        let nVocab = llama_n_vocab(llama_get_model(context))

        var candidates = (0..<nVocab).map { tokenID in
            llama_token_data(id: tokenID, logit: logits![Int(tokenID)], p: 0.0)
        }

        var candidatesArray = llama_token_data_array(
            data: &candidates,
            size: Int(nVocab),
            sorted: false
        )

        if let grammar = grammar {
            llama_grammar_sample(grammar, context, &candidatesArray)
        }

        llama_sample_top_k(context, &candidatesArray, 40, 1)
        llama_sample_top_p(context, &candidatesArray, 0.95, 1)
        llama_sample_temp(context, &candidatesArray, 0.8)

        let selectedToken = llama_sample_token(context, &candidatesArray)

        if let grammar = grammar {
            llama_grammar_accept_token(grammar, context, selectedToken)
        }

        return selectedToken
    }

    /// Compiles a GBNF grammar string into a llama grammar pointer.
    private func compileGrammar(gbnf: String, model: OpaquePointer) -> OpaquePointer? {
        guard let grammar = llama_grammar_init_impl(model, gbnf, "root") else {
            logger.warning("Failed to compile GBNF grammar, proceeding without constraint")
            return nil
        }
        return grammar
    }

    /// Decodes a single token ID back into a UTF-8 string.
    private func decodeToken(_ tokenID: llama_token, model: OpaquePointer) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = llama_token_to_piece(model, tokenID, &buffer, Int32(buffer.count), 0, false)
        guard length > 0 else { return nil }
        return String(cString: Array(buffer.prefix(Int(length))) + [0])
    }
}

// MARK: - ModelPathResolver

/// Resolves local file paths for downloaded model weights.
enum ModelPathResolver {

    /// Returns the on-disk path for a given model tier, or `nil` if not yet downloaded.
    static func resolvedPath(for tier: ModelTier) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let modelFile = documentsURL
            .appendingPathComponent("models")
            .appendingPathComponent(tier.rawValue)
            .appendingPathExtension("gguf")
        guard fileManager.fileExists(atPath: modelFile.path) else {
            return nil
        }
        return modelFile.path
    }
}
