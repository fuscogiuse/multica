import Foundation

/// Listens to the server's websocket and calls `onEvent` for each message.
/// Used as a "something changed" signal: the store refetches what is on screen.
public final class LiveSocket: @unchecked Sendable {
    private let url: URL
    private let token: String
    private let onEvent: @Sendable () -> Void
    private var task: URLSessionWebSocketTask?
    private var stopped = false
    private var attempt = 0
    private let session = URLSession(configuration: .default)

    public init(url: URL, token: String, onEvent: @escaping @Sendable () -> Void) {
        self.url = url
        self.token = token
        self.onEvent = onEvent
    }

    public func start() {
        stopped = false
        connect()
    }

    public func stop() {
        stopped = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func connect() {
        guard !stopped else { return }
        let socket = session.webSocketTask(with: url)
        task = socket
        socket.resume()
        let auth = "{\"type\":\"auth\",\"payload\":{\"token\":\"\(token)\"}}"
        socket.send(.string(auth)) { [weak self] error in
            if error != nil { self?.scheduleReconnect() }
        }
        receive(on: socket)
    }

    private func receive(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            guard let self, !self.stopped else { return }
            switch result {
            case .failure:
                self.scheduleReconnect()
            case .success(let message):
                self.attempt = 0
                if case .string(let text) = message, text.contains("auth_ack") == false {
                    self.onEvent()
                }
                self.receive(on: socket)
            }
        }
    }

    private func scheduleReconnect() {
        guard !stopped else { return }
        attempt += 1
        let delay = min(30.0, pow(2.0, Double(min(attempt, 5))))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
}
