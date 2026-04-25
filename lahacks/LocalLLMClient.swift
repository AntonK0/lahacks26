import Foundation
import ZeticMLange

actor LocalLLMClient {
    private var model: ZeticMLangeLLMModel?

    func prepare(onDownload: @escaping @MainActor @Sendable (Float) -> Void) async throws {
        _ = try loadModel(onDownload: onDownload)
    }

    func generateResponse(
        for prompt: String,
        onTextUpdate: @escaping @MainActor @Sendable (String) -> Void,
        onVisibleTextUpdate: (@Sendable (String) async -> Void)? = nil
    ) async throws {
        let model = try loadModel(onDownload: { _ in })
        try model.cleanUp()
        _ = try model.run(prompt)

        var responseFilter = AssistantResponseFilter()
        while !Task.isCancelled {
            let result = model.waitForNextToken()

            if result.generatedTokens == 0 {
                break
            }

            if !result.token.isEmpty {
                let visibleText = responseFilter.append(result.token)

                await MainActor.run {
                    onTextUpdate(visibleText)
                }

                await onVisibleTextUpdate?(visibleText)
            }
        }
    }

    func release() {
        model?.forceDeinit()
        model = nil
    }

    private func loadModel(onDownload: @escaping @MainActor @Sendable (Float) -> Void) throws -> ZeticMLangeLLMModel {
        if let model {
            return model
        }

        let loadedModel = try loadExplicitModel(apType: .CPU, contextLength: 2048, onDownload: onDownload)
        model = loadedModel

        return loadedModel
    }

    private func loadExplicitModel(
        apType: APType,
        contextLength: Int,
        onDownload: @escaping @MainActor @Sendable (Float) -> Void
    ) throws -> ZeticMLangeLLMModel {
        let loadedModel = try ZeticMLangeLLMModel(
            personalKey: MelangeSecrets.personalKey,
            name: MelangeSecrets.modelName,
            version: MelangeSecrets.modelVersion,
            target: .LLAMA_CPP,
            quantType: .GGUF_QUANT_Q4_K_M,
            apType: apType,
            initOption: LLMInitOption(
                kvCacheCleanupPolicy: .CLEAN_UP_ON_FULL,
                nCtx: contextLength
            ),
            onDownload: { progress in
                Task { @MainActor in
                    onDownload(progress)
                }
            }
        )

        return loadedModel
    }
}
