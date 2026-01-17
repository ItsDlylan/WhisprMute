import Foundation

class DiscordRPC {
    private var socket: Int32 = -1
    private var isConnected = false

    // Discord RPC opcodes
    private enum Opcode: UInt32 {
        case handshake = 0
        case frame = 1
        case close = 2
        case ping = 3
        case pong = 4
    }

    init() {
        connect()
    }

    deinit {
        disconnect()
    }

    func connect() -> Bool {
        // Discord IPC socket is at /var/folders/.../T/discord-ipc-{0-9}
        // We need to find the temp directory and try each pipe
        let tempDir = NSTemporaryDirectory()

        for i in 0..<10 {
            let pipePath = (tempDir as NSString).appendingPathComponent("discord-ipc-\(i)")

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

            let connectResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.connect(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }

            if connectResult == 0 {
                print("[DiscordRPC] Connected to discord-ipc-\(i)")
                isConnected = true

                // Send handshake - we need a client ID for this
                // For now, we'll try without full OAuth
                if sendHandshake() {
                    return true
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
    }

    private func sendHandshake() -> Bool {
        let handshake: [String: Any] = [
            "v": 1,
            "client_id": "1462209836644176025"
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
