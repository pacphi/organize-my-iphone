import Foundation

/// The response to an HTTP request: body plus status code.
public struct HTTPResponse: Sendable {
    public var body: Data
    public var statusCode: Int

    public init(body: Data, statusCode: Int) {
        self.body = body
        self.statusCode = statusCode
    }
}

/// Sends HTTP requests. Tests substitute a fake so nothing touches the network.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(body: data, statusCode: statusCode)
    }
}

public enum HTTPError: Error, Equatable, Sendable, LocalizedError {
    case unexpectedStatus(Int, service: String)
    case unreadableResponse(service: String)

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status, let service):
            return "\(service) answered with HTTP \(status)."
        case .unreadableResponse(let service):
            return "\(service) sent a reply that could not be read."
        }
    }
}
