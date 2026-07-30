import Foundation

class AIService {
    static let shared = AIService()
    
    private let endpointString = "https://generativelanguage.googleapis.com/v1beta/models"
    
    private init() {}
    
    // JSON Request Payload Structures
    struct GeminiRequest: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        struct SystemInstruction: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let contents: [Content]
        let systemInstruction: SystemInstruction?
    }
    
    // JSON Response Parser Structures
    struct GeminiResponse: Codable {
        struct Candidate: Codable {
            struct Content: Codable {
                struct Part: Codable {
                    let text: String
                }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]?
    }
    
    struct GeminiErrorResponse: Codable {
        struct ErrorDetails: Codable {
            let code: Int
            let message: String
            let status: String
        }
        let error: ErrorDetails
    }
    
    // Configurable model name stored in UserDefaults
    var modelName: String {
        get {
            let model = UserDefaults.standard.string(forKey: "com.orbit.selectedModel") ?? "gemini-3.6-flash"
            if model == "gemini-1.5-pro" {
                return "gemini-3.6-flash"
            }
            return model
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "com.orbit.selectedModel")
        }
    }
    
    func generateResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        generateResponse(prompt: prompt, retryWithFallback: true, completion: completion)
    }
    
    private func generateResponse(prompt: String, retryWithFallback: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        // Read key from Keychain at call-time
        guard let apiKey = KeychainHelper.shared.readKey() else {
            completion(.failure(NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Gemini API key configured in Keychain"])))
            return
        }
        
        let urlString = "\(endpointString)/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "AIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini endpoint URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Define standard system instruction
        let systemPromptText = "Orbit is a concise, helpful Mac assistant. It must not claim it performed a Mac action unless MacActionService actually performed it."
        let systemInstruction = GeminiRequest.SystemInstruction(parts: [.init(text: systemPromptText)])
        
        let requestBody = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            systemInstruction: systemInstruction
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "AIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response data received from Gemini API"])))
                return
            }
            
            // Check for HTTP errors or quota limits
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // If it's a 404 (Not Found / Model Unavailable) and we haven't retried yet,
                // and the current model is NOT gemini-3.6-flash, fallback to gemini-3.6-flash.
                if httpResponse.statusCode == 404, retryWithFallback, self.modelName != "gemini-3.6-flash" {
                    let oldModel = self.modelName
                    self.modelName = "gemini-3.6-flash"
                    print("Model \(oldModel) returned 404. Falling back to gemini-3.6-flash and retrying.")
                    self.generateResponse(prompt: prompt, retryWithFallback: false, completion: completion)
                    return
                }
                
                var errorMessage = "Gemini API returned status code \(httpResponse.statusCode)."
                if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                    errorMessage += " Details: \(errorResponse.error.message)"
                } else if let rawString = String(data: data, encoding: .utf8) {
                    errorMessage += " Raw Response: \(rawString)"
                }
                
                // Add friendly guidance based on HTTP status codes
                if httpResponse.statusCode == 404 {
                    errorMessage += " (The model '\(self.modelName)' or endpoint was not found. Please verify the model name configuration in Settings.)"
                } else if httpResponse.statusCode == 400 || httpResponse.statusCode == 403 {
                    errorMessage += " (API Key validation failed. Please check that your Gemini API key is correct and valid in Settings.)"
                } else if httpResponse.statusCode == 429 {
                    errorMessage += " (Rate limit exceeded or quota exhausted. Please try again later.)"
                }
                
                let statusError = NSError(
                    domain: "AIService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                completion(.failure(statusError))
                return
            }
            
            do {
                let responseDecoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                if let text = responseDecoded.candidates?.first?.content.parts.first?.text {
                    completion(.success(text))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid or empty response format from Gemini API"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
