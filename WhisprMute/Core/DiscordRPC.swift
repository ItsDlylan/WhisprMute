import Foundation

class DiscordRPC {
    private var socket: Int32 = -1
    private var isConnected = false

    // Client ID loaded from environment or config file
    private let clientId: String? = {
        // Try environment variable first
        if let envId = ProcessInfo.processInfo.environment["DISCORD_CLIENT_ID"] {
            return envId
        }
        // Try loading from ~/.whisprmute config file
        let configPath = NSHomeDirectory() + "/.whisprmute"
        if let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
            for line in config.components(separatedBy: "\n") {
                if line.hasPrefix("DISCORD_CLIENT_ID=") {
                    return String(line.dropFirst("DISCORD_CLIENT_ID=".count)).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }()

    // Discord RPC opcodes
    private enum Opcode: UInt32 {
        case handshake = 0
        case frame = 1
        case close = 2
        case ping = 3
        case pong = 4
    }

    init() {
        print("[DiscordRPC] Client ID: \(clientId ?? "NOT SET")")
        connect()
    }

    deinit {
        disconnect()
    }

    func connect() -> Bool {
        // Discord IPC socket is at /var/folders/.../T/discord-ipc-{0-9}
        // We need to find the temp directory and try each pipe
        let tempDir = NSTemporaryDirectory()
        print("[DiscordRPC] Looking for IPC socket in: \(tempDir)")

        for i in 0..<10 {
            let pipePath = (tempDir as NSString).appendingPathComponent("discord-ipc-\(i)")
            print("[DiscordRPC] Trying: \(pipePath)")

            socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            if socket == -1 {
                continue
            }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)

            // Copy path to sun_path
            let pathBytes = pipePath.utf8CString
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                let bound = ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    for (index, byte) in pathBytes.enumerated() where index < 104 {
                        dest[index] = byte
                    }
                }
            }

            // Check if socket file exists
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
                    return true
                } else {
                    print("[DiscordRPC] Handshake failed")
                }
            } else {
                print("[DiscordRPC] Connect failed for ipc-\(i): \(errno)")
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
    }

    private func sendHandshake() -> Bool {
        guard let clientId = clientId else {
            print("[DiscordRPC] No client ID configured. Set DISCORD_CLIENT_ID env var or add to ~/.whisprmute")
            return false
        }

        let handshake: [String: Any] = [
            "v": 1,
            "client_id": clientId
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: handshake),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        return sendFrame(opcode: .handshake, data: jsonString)
    }

    private func sendFrame(opcode: Opcode, data: String) -> Bool {
        guard socket != -1 else { return false }

        let dataBytes = Array(data.utf8)
        let length = UInt32(dataBytes.count)

        // Build frame: opcode (4 bytes LE) + length (4 bytes LE) + data
        var frame = Data()
        var op = opcode.rawValue.littleEndian
        var len = length.littleEndian

        frame.append(Data(bytes: &op, count: 4))
        frame.append(Data(bytes: &len, count: 4))
        frame.append(contentsOf: dataBytes)

        let sent = frame.withUnsafeBytes { ptr in
            Darwin.send(socket, ptr.baseAddress!, frame.count, 0)
        }

        if sent == frame.count {
            // Read response
            if let response = readFrame() {
                print("[DiscordRPC] Response: \(response)")
            }
        }

        return sent == frame.count
    }

    private func readFrame() -> String? {
        guard socket != -1 else { return nil }

        // Read header (8 bytes: 4 for opcode, 4 for length)
        var header = [UInt8](repeating: 0, count: 8)
        let headerRead = Darwin.recv(socket, &header, 8, 0)

        guard headerRead == 8 else { return nil }

        // Parse length (little endian, bytes 4-7)
        let length = UInt32(header[4]) | (UInt32(header[5]) << 8) | (UInt32(header[6]) << 16) | (UInt32(header[7]) << 24)

        guard length > 0 && length < 65536 else { return nil }

        // Read payload
        var payload = [UInt8](repeating: 0, count: Int(length))
        let payloadRead = Darwin.recv(socket, &payload, Int(length), 0)

        guard payloadRead == Int(length) else { return nil }

        return String(bytes: payload, encoding: .utf8)
    }

    private func sendCommand(_ cmd: String, args: [String: Any], nonce: String = UUID().uuidString) -> Bool {
        let payload: [String: Any] = [
            "cmd": cmd,
            "args": args,
            "nonce": nonce
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[DiscordRPC] Failed to serialize command")
            return false
        }

        return sendFrame(opcode: .frame, data: jsonString)
    }

    func setMute(_ muted: Bool) -> Bool {
        if !isConnected {
            print("[DiscordRPC] Not connected, attempting to connect...")
            if !connect() {
                return false
            }
        }

        // SET_VOICE_SETTINGS command
        let args: [String: Any] = [
            "mute": muted
        ]

        let success = sendCommand("SET_VOICE_SETTINGS", args: args)
        print("[DiscordRPC] setMute(\(muted)): \(success)")
        return success
    }
}
