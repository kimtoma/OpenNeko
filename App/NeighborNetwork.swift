import CryptoKit
import Foundation
import Network
import OpenNekoKit
import Security

final class NeighborNetwork: NSObject {
    private static let serviceType = "_openneko._tcp."
    private static let serviceDomain = "local."
    private static let peerTTL: TimeInterval = 12

    private let myID: String
    private let getSelf: () -> NeighborSelf
    private let onEvent: (NeighborEvent) -> Void
    private var currentPresence: NeighborPresence = .idle

    private var listener: NWListener?
    private var service: NetService?
    private var browser: NetServiceBrowser?
    private var resolvingServices: [String: NetService] = [:]
    private var serviceNameToPeerID: [String: String] = [:]
    private var connections: [ObjectIdentifier: NeighborPeerConnection] = [:]
    private var peerConnections: [String: NeighborPeerConnection] = [:]
    private var peerBook = NeighborPeerBook()
    private var pruneTimer: Timer?

    init(
        myID: String,
        getSelf: @escaping () -> NeighborSelf,
        onEvent: @escaping (NeighborEvent) -> Void
    ) {
        self.myID = myID
        self.getSelf = getSelf
        self.onEvent = onEvent
        super.init()
    }

    var peers: [NeighborPeer] {
        peerBook.peers
    }

    func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in
                DispatchQueue.main.async {
                    self?.addConnection(connection, knownPeerID: nil, isOutgoing: false)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleListenerState(state)
                }
            }
            listener.start(queue: .main)
        } catch {
            NSLog("[openNeko] neighbor listener failed: \(error)")
        }
    }

    func stop() {
        pruneTimer?.invalidate()
        pruneTimer = nil

        broadcast(.bye())
        for connection in connections.values {
            connection.close()
        }
        connections.removeAll()
        peerConnections.removeAll()
        peerBook = NeighborPeerBook()

        browser?.stop()
        browser = nil
        for service in resolvingServices.values {
            service.stop()
        }
        resolvingServices.removeAll()
        serviceNameToPeerID.removeAll()

        service?.stop()
        service = nil
        listener?.cancel()
        listener = nil
    }

    func setPresence(_ presence: NeighborPresence) {
        guard currentPresence != presence else { return }
        currentPresence = presence
        broadcast(.presence(presence))
    }

    func sendWave() {
        broadcast(.wave())
    }

    func sendWave(to peerID: String) {
        send(.wave(), to: peerID)
    }

    func sendGreeting(key: Int) {
        guard let message = NeighborMessage.greeting(key: key) else { return }
        broadcast(message)
    }

    func sendGreeting(to peerID: String, key: Int) {
        guard let message = NeighborMessage.greeting(key: key) else { return }
        send(message, to: peerID)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port else { return }
            publish(port: port)
            browse()
            startPruneTimer()
        case .failed(let error):
            NSLog("[openNeko] neighbor listener failed: \(error)")
            stop()
        default:
            break
        }
    }

    private func publish(port: NWEndpoint.Port) {
        service?.stop()
        let service = NetService(
            domain: Self.serviceDomain,
            type: Self.serviceType,
            name: "openneko-\(myID)",
            port: Int32(port.rawValue)
        )
        let selfInfo = getSelf()
        service.setTXTRecord(NetService.data(fromTXTRecord: [
            "id": data(myID),
            "name": data(selfInfo.name),
            "skin": data(selfInfo.skin),
            "v": data("1"),
        ]))
        service.delegate = self
        service.publish()
        self.service = service
    }

    private func browse() {
        browser?.stop()
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: Self.serviceType, inDomain: Self.serviceDomain)
        self.browser = browser
    }

    private func startPruneTimer() {
        pruneTimer?.invalidate()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            guard let self else { return }
            let expired = peerBook.prune(now: now(), ttl: Self.peerTTL)
            for peer in expired {
                peerConnections.removeValue(forKey: peer.id)?.close()
                onEvent(.left(peer))
            }
        }
    }

    private func connectToResolvedService(_ service: NetService) {
        let txt = Self.txtDictionary(service)
        guard let peerID = txt["id"], peerID != myID else { return }
        serviceNameToPeerID[service.name] = peerID

        let peer = NeighborPeer(
            id: peerID,
            name: txt["name"] ?? "",
            skin: txt["skin"] ?? SkinManager.defaultID,
            presence: .idle,
            lastSeen: now()
        )
        if let result = peerBook.addOrUpdate(peer), result.isNew {
            onEvent(.joined(result.peer))
        }

        guard peerID > myID else { return }
        guard peerConnections[peerID] == nil else { return }
        guard let hostName = service.hostName, service.port > 0 else { return }
        guard let port = NWEndpoint.Port(rawValue: UInt16(service.port)) else { return }

        let host = NWEndpoint.Host(hostName.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
        let connection = NWConnection(host: host, port: port, using: .tcp)
        addConnection(connection, knownPeerID: peerID, isOutgoing: true)
    }

    private func addConnection(_ connection: NWConnection, knownPeerID: String?, isOutgoing: Bool) {
        let socket = NeighborPeerConnection(connection: connection, isOutgoing: isOutgoing)
        connections[ObjectIdentifier(socket)] = socket
        if let knownPeerID {
            bind(socket, to: knownPeerID)
        }
        socket.onReady = { [weak self, weak socket] in
            guard let self, let socket else { return }
            if isOutgoing {
                self.sendHello(on: socket)
            }
        }
        socket.onText = { [weak self, weak socket] text in
            guard let self, let socket else { return }
            guard let message = NeighborMessageCodec.decodeLine(text) else { return }
            self.handle(message, from: socket)
        }
        socket.onClose = { [weak self, weak socket] in
            guard let self, let socket else { return }
            self.removeConnection(socket)
        }
        socket.start()
    }

    private func bind(_ socket: NeighborPeerConnection, to peerID: String) {
        guard !peerID.isEmpty else { return }
        if let old = peerConnections[peerID], old !== socket {
            old.close()
        }
        socket.peerID = peerID
        peerConnections[peerID] = socket
    }

    private func removeConnection(_ socket: NeighborPeerConnection) {
        connections.removeValue(forKey: ObjectIdentifier(socket))
        guard let peerID = socket.peerID, peerConnections[peerID] === socket else { return }
        peerConnections.removeValue(forKey: peerID)
    }

    private func handle(_ message: NeighborMessage, from socket: NeighborPeerConnection) {
        switch message.kind {
        case .hello:
            guard let peerID = message.id, peerID != myID else { return }
            bind(socket, to: peerID)
            let peer = NeighborPeer(
                id: peerID,
                name: message.name ?? "",
                skin: message.skin ?? SkinManager.defaultID,
                presence: peerBook.peer(id: peerID)?.presence ?? .idle,
                lastSeen: now()
            )
            if let result = peerBook.addOrUpdate(peer) {
                if result.isNew {
                    onEvent(.joined(result.peer))
                }
            }
            if !socket.hasSentHello {
                sendHello(on: socket)
            }
            socket.send(.presence(currentPresence))

        case .presence:
            guard let peerID = socket.peerID, let presence = message.presence else { return }
            let peer = peerBook.setPresence(id: peerID, presence, lastSeen: now())
                ?? NeighborPeer(id: peerID, presence: presence, lastSeen: now())
            _ = peerBook.addOrUpdate(peer)
            onEvent(.presence(peer))

        case .wave:
            guard let peer = currentPeer(for: socket) else { return }
            onEvent(.wave(peer))

        case .greeting:
            guard let peer = currentPeer(for: socket), let key = message.greetingKey else { return }
            onEvent(.greeting(peer, key: key))

        case .bye:
            guard let peerID = socket.peerID else { return }
            if let peer = peerBook.remove(id: peerID) {
                onEvent(.left(peer))
            }
            peerConnections.removeValue(forKey: peerID)
            socket.close()
        }
    }

    private func currentPeer(for socket: NeighborPeerConnection) -> NeighborPeer? {
        guard let peerID = socket.peerID else { return nil }
        return peerBook.touch(id: peerID, lastSeen: now())
            ?? NeighborPeer(id: peerID, lastSeen: now())
    }

    private func sendHello(on socket: NeighborPeerConnection) {
        let selfInfo = getSelf()
        guard let hello = NeighborMessage.hello(id: myID, name: selfInfo.name, skin: selfInfo.skin) else { return }
        socket.send(hello)
        socket.hasSentHello = true
    }

    private func broadcast(_ message: NeighborMessage) {
        for connection in peerConnections.values {
            connection.send(message)
        }
    }

    private func send(_ message: NeighborMessage, to peerID: String) {
        peerConnections[peerID]?.send(message)
    }

    private func now() -> TimeInterval {
        Date().timeIntervalSince1970
    }

    private static func txtDictionary(_ service: NetService) -> [String: String] {
        guard let record = service.txtRecordData() else { return [:] }
        return NetService.dictionary(fromTXTRecord: record).reduce(into: [:]) { result, item in
            result[item.key] = String(data: item.value, encoding: .utf8)
        }
    }

    private func data(_ string: String) -> Data {
        Data(string.utf8)
    }
}

extension NeighborNetwork: NetServiceDelegate, NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard service.name != "openneko-\(myID)" else { return }
        resolvingServices[service.name] = service
        service.delegate = self
        service.resolve(withTimeout: 4)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let peerID = serviceNameToPeerID.removeValue(forKey: service.name)
        resolvingServices.removeValue(forKey: service.name)
        guard let peerID, let peer = peerBook.remove(id: peerID) else { return }
        peerConnections.removeValue(forKey: peerID)?.close()
        onEvent(.left(peer))
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        resolvingServices.removeValue(forKey: sender.name)
        connectToResolvedService(sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolvingServices.removeValue(forKey: sender.name)
    }
}

struct NeighborSelf {
    let name: String
    let skin: String
}

private final class NeighborPeerConnection {
    enum Stage {
        case serverHandshake
        case clientHandshake
        case frames
        case closed
    }

    let connection: NWConnection
    let isOutgoing: Bool
    var peerID: String?
    var hasSentHello = false
    var onReady: (() -> Void)?
    var onText: ((String) -> Void)?
    var onClose: (() -> Void)?

    private var stage: Stage
    private var buffer = Data()
    private var clientKey = ""

    init(connection: NWConnection, isOutgoing: Bool) {
        self.connection = connection
        self.isOutgoing = isOutgoing
        self.stage = isOutgoing ? .clientHandshake : .serverHandshake
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleState(state)
            }
        }
        connection.start(queue: .main)
        receive()
    }

    func send(_ message: NeighborMessage) {
        guard stage == .frames else { return }
        guard let text = String(data: (try? NeighborMessageCodec.encode(message)) ?? Data(), encoding: .utf8) else {
            return
        }
        sendText(text)
    }

    func close() {
        stage = .closed
        connection.cancel()
    }

    private func handleState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            if isOutgoing {
                sendClientHandshake()
            }
        case .failed, .cancelled:
            stage = .closed
            onClose?()
        default:
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self] data, _, isComplete, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.buffer.append(data)
                    self.processBuffer()
                }
                if error != nil || isComplete {
                    self.stage = .closed
                    self.onClose?()
                    return
                }
                if self.stage != .closed {
                    self.receive()
                }
            }
        }
    }

    private func processBuffer() {
        switch stage {
        case .serverHandshake:
            processServerHandshake()
        case .clientHandshake:
            processClientHandshake()
        case .frames:
            processFrames()
        case .closed:
            break
        }
    }

    private func processServerHandshake() {
        guard let range = buffer.range(of: Data([13, 10, 13, 10])) else { return }
        let headerData = buffer[..<range.upperBound]
        let remaining = buffer[range.upperBound...]
        buffer = Data(remaining)

        guard
            let header = String(data: headerData, encoding: .utf8),
            let key = Self.headerValue("Sec-WebSocket-Key", in: header)
        else {
            close()
            return
        }

        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(Self.acceptKey(key))\r
        \r
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil {
                    self.close()
                    return
                }
                self.stage = .frames
                self.onReady?()
                self.processFrames()
            }
        })
    }

    private func processClientHandshake() {
        guard let range = buffer.range(of: Data([13, 10, 13, 10])) else { return }
        let headerData = buffer[..<range.upperBound]
        let remaining = buffer[range.upperBound...]
        buffer = Data(remaining)

        guard
            let header = String(data: headerData, encoding: .utf8),
            header.contains("101")
        else {
            close()
            return
        }

        stage = .frames
        onReady?()
        processFrames()
    }

    private func processFrames() {
        while let frame = popFrame() {
            switch frame {
            case .text(let text):
                onText?(text)
            case .ping(let payload):
                sendFrame(opcode: 0xA, payload: payload, masked: isOutgoing)
            case .close:
                close()
                return
            case .ignore:
                break
            }
        }
    }

    private enum Frame {
        case text(String)
        case ping(Data)
        case close
        case ignore
    }

    private func popFrame() -> Frame? {
        guard buffer.count >= 2 else { return nil }
        let first = buffer[buffer.startIndex]
        let second = buffer[buffer.startIndex + 1]
        let opcode = first & 0x0F
        let masked = (second & 0x80) != 0
        var payloadLength = Int(second & 0x7F)
        var index = 2

        if payloadLength == 126 {
            guard buffer.count >= 4 else { return nil }
            payloadLength = (Int(buffer[buffer.startIndex + 2]) << 8) | Int(buffer[buffer.startIndex + 3])
            index = 4
        } else if payloadLength == 127 {
            guard buffer.count >= 10 else { return nil }
            var length: UInt64 = 0
            for offset in 2..<10 {
                length = (length << 8) | UInt64(buffer[buffer.startIndex + offset])
            }
            guard length <= UInt64(NeighborMessageCodec.maxRawBytes) else {
                close()
                return nil
            }
            payloadLength = Int(length)
            index = 10
        }

        var mask: [UInt8] = []
        if masked {
            guard buffer.count >= index + 4 else { return nil }
            mask = (0..<4).map { buffer[buffer.startIndex + index + $0] }
            index += 4
        }

        guard payloadLength <= NeighborMessageCodec.maxRawBytes else {
            close()
            return nil
        }
        guard buffer.count >= index + payloadLength else { return nil }

        var payload = [UInt8](buffer[(buffer.startIndex + index)..<(buffer.startIndex + index + payloadLength)])
        buffer.removeSubrange(buffer.startIndex..<(buffer.startIndex + index + payloadLength))

        if masked {
            for idx in payload.indices {
                payload[idx] ^= mask[idx % 4]
            }
        }

        switch opcode {
        case 0x1:
            guard let text = String(data: Data(payload), encoding: .utf8) else { return .ignore }
            return .text(text)
        case 0x8:
            return .close
        case 0x9:
            return .ping(Data(payload))
        case 0xA:
            return .ignore
        default:
            return .ignore
        }
    }

    private func sendClientHandshake() {
        clientKey = Self.randomKey(byteCount: 16)
        let request = """
        GET / HTTP/1.1\r
        Host: openneko.local\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Key: \(clientKey)\r
        Sec-WebSocket-Version: 13\r
        \r
        """
        connection.send(content: Data(request.utf8), completion: .contentProcessed { [weak self] error in
            if error != nil {
                DispatchQueue.main.async { self?.close() }
            }
        })
    }

    private func sendText(_ text: String) {
        sendFrame(opcode: 0x1, payload: Data(text.utf8), masked: isOutgoing)
    }

    private func sendFrame(opcode: UInt8, payload: Data, masked: Bool) {
        guard stage == .frames, payload.count <= NeighborMessageCodec.maxRawBytes else { return }
        var frame = Data()
        frame.append(0x80 | opcode)
        if payload.count < 126 {
            frame.append((masked ? 0x80 : 0) | UInt8(payload.count))
        } else {
            frame.append((masked ? 0x80 : 0) | 126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        }

        if masked {
            let key = Self.randomBytes(byteCount: 4)
            frame.append(contentsOf: key)
            let bytes = [UInt8](payload)
            for idx in bytes.indices {
                frame.append(bytes[idx] ^ key[idx % 4])
            }
        } else {
            frame.append(payload)
        }

        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            if error != nil {
                DispatchQueue.main.async { self?.close() }
            }
        })
    }

    private static func headerValue(_ name: String, in header: String) -> String? {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            guard parts[0].trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame else {
                continue
            }
            return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func acceptKey(_ key: String) -> String {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data((key + magic).utf8))
        return Data(digest).base64EncodedString()
    }

    private static func randomKey(byteCount: Int) -> String {
        Data(randomBytes(byteCount: byteCount)).base64EncodedString()
    }

    private static func randomBytes(byteCount: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        if SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes) != errSecSuccess {
            for idx in bytes.indices {
                bytes[idx] = UInt8.random(in: UInt8.min...UInt8.max)
            }
        }
        return bytes
    }
}
