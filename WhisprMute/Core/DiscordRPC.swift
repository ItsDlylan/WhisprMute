import Foundation

class DiscordRPC {
    private var socket: Int32 = -1
    private var isConnected = false
    private var isAuthenticated = false
    private var accessToken: String?

    // Load config from ~/.whisprmute
    private static func loadConfig() -> [String: String] {
        var config: [String: String] = [:]

        // Environment variables take precedence
        if let envId = ProcessInfo.processInfo.environment["DISCORD_CLIENT_ID"] {
            config["client_id"] = envId
        }
        if let envSecret = ProcessInfo.processInfo.environment["DISCORD_CLIENT_SECRET"] {
            config["client_secret"] = envSecret
        }

        // Load from config file
        let configPath = NSHomeDirectory() + "/.whisprmute"
        if let fileContent = try? String(contentsOfFile: configPath, encoding: .utf8) {
            for line in fileContent.components(separatedBy: "\n") {
                if line.hasPrefix("DISCORD_CLIENT_ID=") && config["client_id"] == nil {
                    config["client_id"] = String(line.dropFirst("DISCORD_CLIENT_ID=".count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("DISCORD_CLIENT_SECRET=") && config["client_secret"] == nil {
                    config["client_secret"] = String(line.dropFirst("DISCORD_CLIENT_SECRET=".count)).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return config
    }

    private let clientId: String? = loadConfig()["client_id"]
    private let clientSecret: String? = loadConfig()["client_secret"]

    // Load saved access token
    private var savedAccessToken: String? {
        get {
            let tokenPath = NSHomeDirectory() + "/.whisprmute_token"
            return try? String(contentsOfFile: tokenPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            let tokenPath = NSHomeDirectory() + "/.whisprmute_token"
            if let token = newValue {
                try? token.write(toFile: tokenPath, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(atPath: tokenPath)
            }
        }
    }

    private enum Opcode: UInt32 {
        case handshake = 0
        case frame = 1
        case close = 2
        case ping = 3
        case pong = 4
    }

    init() {
        print("[DiscordRPC] Client ID: \(clientId ?? "NOT SET")")
        print("[DiscordRPC] Client Secret: \(clientSecret != nil ? "configured" : "NOT SET")")
        accessToken = savedAccessToken
        if accessToken != nil {
            print("[DiscordRPC] Found saved access token")
        }
        connect()
    }

    deinit {
        disconnect()
    }

    func connect() -> Bool {
        let tempDir = NSTemporaryDirectory()
        print("[DiscordRPC] Looking for IPC socket in: \(tempDir)")

        for i in 0..<10 {
            let pipePath = (tempDir as NSString).appendingPathComponent("discord-ipc-\(i)")

            socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            if socket == -1 { continue }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)

            let pathBytes = pipePath.utf8CString
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    for (index, byte) in pathBytes.enumerated() where index < 104 {
                        dest[index] = byte
                    }
                }
            }

            if !FileManager.default.fileExists(atPath: pipePath) {
                Darwin.close(socket)
                socket = -1
                continue
            }

            let connectResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.connect(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }

            if connectResult == 0 {
                print("[DiscordRPC] Connected to discord-ipc-\(i)")
                isConnected = true

                if sendHandshake() {
                    print("[DiscordRPC] Handshake successful")

                    // Try to authenticate with saved token first
                    if let token = accessToken {
                        if authenticate(with: token) {
                            print("[DiscordRPC] Authenticated with saved token")
                            return true
                        } else {
                            print("[DiscordRPC] Saved token invalid, need reauthorization")
                            savedAccessToken = nil
                            accessToken = nil
                        }
                    }

                    // Need to authorize
                    if authorize() {
                        return true
                    }
                }
            }

            Darwin.close(socket)
            socket = -1
        }

        print("[DiscordRPC] Failed to connect to any Discord IPC socket")
        return false
    }

    func disconnect() {
        if socket != -1 {
            Darwin.close(socket)
            socket = -1
        }
        isConnected = false
        isAuthenticated = false
    }

    private func sendHandshake() -> Bool {
        guard let clientId = clientId else {
            print("[DiscordRPC] No client ID configured")
            return false
        }

        let handshake: [String: Any] = ["v": 1, "client_id": clientId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: handshake),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        if sendFrameRaw(opcode: .handshake, data: jsonString) {
            // Read READY response
            if let response = readFrame() {
                print("[DiscordRPC] Handshake response: \(response.prefix(200))...")
                return response.contains("READY")
            }
        }
        return false
    }

    private func authorize() -> Bool {
        guard let clientId = clientId else {
            print("[DiscordRPC] No client ID configured")
            return false
        }
        guard let clientSecret = clientSecret else {
            print("[DiscordRPC] No client secret configured - add DISCORD_CLIENT_SECRET to ~/.whisprmute")
            return false
        }

        print("[DiscordRPC] Requesting authorization (check Discord for prompt)...")

        let args: [String: Any] = [
            "client_id": clientId,
            "scopes": ["rpc", "rpc.voice.read", "rpc.voice.write"]
        ]

        if sendCommand("AUTHORIZE", args: args) {
            if let response = readFrame() {
                print("[DiscordRPC] Auth response: \(response.prefix(300))...")

                // Parse the response to get the code
                if let data = response.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any],
                   let code = dataObj["code"] as? String {
                    print("[DiscordRPC] Got authorization code, exchanging for access token...")

                    // Exchange authorization code for access token
                    if let token = exchangeCodeForToken(code: code, clientId: clientId, clientSecret: clientSecret) {
                        print("[DiscordRPC] Got access token")
                        accessToken = token
                        savedAccessToken = token
                        return authenticate(with: token)
                    } else {
                        print("[DiscordRPC] Failed to exchange code for token")
                    }
                } else if response.contains("ERROR") {
                    print("[DiscordRPC] Authorization denied or error")
                }
            }
        }
        return false
    }

    private func exchangeCodeForToken(code: String, clientId: String, clientSecret: String) -> String? {
        let url = URL(string: "https://discord.com/api/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&client_secret=\(clientSecret)&grant_type=authorization_code&code=\(code)&redirect_uri=http://localhost"
        request.httpBody = body.data(using: .utf8)

        var accessToken: String?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                print("[DiscordRPC] Token exchange error: \(error)")
                return
            }

            guard let data = data else {
                print("[DiscordRPC] No data from token exchange")
                return
            }

            if let responseStr = String(data: data, encoding: .utf8) {
                print("[DiscordRPC] Token exchange response: \(responseStr.prefix(200))...")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                accessToken = token
            }
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 10)

        return accessToken
    }

    private func authenticate(with token: String) -> Bool {
        let args: [String: Any] = ["access_token": token]

        if sendCommand("AUTHENTICATE", args: args) {
            if let response = readFrame() {
                print("[DiscordRPC] Authenticate response: \(response.prefix(200))...")
                if response.contains("\"evt\":\"ERROR\"") {
                    isAuthenticated = false
                    return false
                }
                isAuthenticated = true
                return true
            }
        }
        return false
    }

    private func sendFrameRaw(opcode: Opcode, data: String) -> Bool {
        guard socket != -1 else { return false }

        let dataBytes = Array(data.utf8)
        let length = UInt32(dataBytes.count)

        var frame = Data()
        var op = opcode.rawValue.littleEndian
        var len = length.littleEndian

        frame.append(Data(bytes: &op, count: 4))
        frame.append(Data(bytes: &len, count: 4))
        frame.append(contentsOf: dataBytes)

        let sent = frame.withUnsafeBytes { ptr in
            Darwin.send(socket, ptr.baseAddress!, frame.count, 0)
        }

        return sent == frame.count
    }

    private func sendCommand(_ cmd: String, args: [String: Any], nonce: String = UUID().uuidString) -> Bool {
        let payload: [String: Any] = [
            "cmd": cmd,
            "args": args,
            "nonce": nonce
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        return sendFrameRaw(opcode: .frame, data: jsonString)
    }

    private func readFrame() -> String? {
        guard socket != -1 else { return nil }

        var header = [UInt8](repeating: 0, count: 8)
        let headerRead = Darwin.recv(socket, &header, 8, 0)
        guard headerRead == 8 else { return nil }

        let length = UInt32(header[4]) | (UInt32(header[5]) << 8) | (UInt32(header[6]) << 16) | (UInt32(header[7]) << 24)
        guard length > 0 && length < 65536 else { return nil }

        var payload = [UInt8](repeating: 0, count: Int(length))
        let payloadRead = Darwin.recv(socket, &payload, Int(length), 0)
        guard payloadRead == Int(length) else { return nil }

        return String(bytes: payload, encoding: .utf8)
    }

    func setMute(_ muted: Bool) -> Bool {
        if !isConnected {
            print("[DiscordRPC] Not connected, attempting to connect...")
            if !connect() { return false }
        }

        if !isAuthenticated {
            print("[DiscordRPC] Not authenticated")
            return false
        }

        let args: [String: Any] = ["mute": muted]

        if sendCommand("SET_VOICE_SETTINGS", args: args) {
            if let response = readFrame() {
                print("[DiscordRPC] setMute response: \(response.prefix(200))...")
                if response.contains("\"evt\":\"ERROR\"") {
                    return false
                }
                return true
            }
        }
        return false
    }

    /// Get current mute state from Discord
    func getMuteState() -> Bool? {
        if !isConnected {
            print("[DiscordRPC] Not connected, attempting to connect...")
            if !connect() { return nil }
        }

        if !isAuthenticated {
            print("[DiscordRPC] Not authenticated")
            return nil
        }

        if sendCommand("GET_VOICE_SETTINGS", args: [:]) {
            if let response = readFrame() {
                print("[DiscordRPC] getMuteState response: \(response.prefix(200))...")

                if let data = response.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any],
                   let muted = dataObj["mute"] as? Bool {
                    return muted
                }
            }
        }
        return nil
    }
}
