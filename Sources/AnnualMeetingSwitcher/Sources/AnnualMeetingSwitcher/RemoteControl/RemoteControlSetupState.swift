import Darwin
import Foundation

struct RemoteControlSetupState: Equatable {
    enum Status: Equatable {
        case disabled
        case enabled
        case failed
    }

    var status: Status
    var host: String?
    var port: UInt16?
    var pairingURL: String?

    static let disabled = RemoteControlSetupState(
        status: .disabled,
        host: nil,
        port: nil,
        pairingURL: nil
    )

    var isEnabled: Bool {
        status == .enabled
    }

    var displayAddress: String? {
        guard let host, let port else { return nil }
        return "\(host):\(port)"
    }

    var statusText: String {
        switch status {
        case .disabled:
            return "未开启"
        case .enabled:
            return "已开启"
        case .failed:
            return "启动失败"
        }
    }

}

enum RemoteControlPairingURLBuilder {
    static func pairingURL(host: String, endpoint: RemoteControlServerEndpoint) -> String {
        "http://\(host):\(endpoint.port)/#token=\(endpoint.token.value)"
    }
}

enum RemoteControlPortPolicy {
    static func makeSessionPort() -> UInt16 {
        UInt16.random(in: 41_000...60_999)
    }
}

enum RemoteControlNetworkAddress {
    static func localIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var fallbackAddress: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let interface = pointer {
            defer { pointer = interface.pointee.ifa_next }

            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            guard let numericAddress = numericHostAddress(from: address) else {
                continue
            }

            let name = String(cString: interface.pointee.ifa_name)
            if name == "en0" {
                return numericAddress
            }
            fallbackAddress = fallbackAddress ?? numericAddress
        }

        return fallbackAddress
    }

    private static func numericHostAddress(from address: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )

        guard result == 0 else {
            return nil
        }
        return String(cString: host)
    }
}
