import MediaPlayer

struct AudioContext {
    let category: AVAudioSession.Category
    let options: AVAudioSession.CategoryOptions

    init() {
        self.category = .playback
        self.options = []
    }

    init(
        category: AVAudioSession.Category,
        options: [AVAudioSession.CategoryOptions]
    ) {
        self.category = category
        self.options = options.reduce(AVAudioSession.CategoryOptions()) { $0.union($1) }
    }

    func activateAudioSession(
        active: Bool
    ) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(active)
    }

    func apply() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(category, options: options)
    }

    static func parse(args: [String: Any]) throws -> AudioContext? {
        guard let categoryString = args["category"] as? String else {
            throw AudioPlayerError.error("Null value received for category")
        }
        guard let category = try parseCategory(category: categoryString) else {
            return nil
        }

        guard let optionStrings = args["options"] as? [String] else {
            throw AudioPlayerError.error("Null value received for options")
        }
        let options = try optionStrings.compactMap {
            try parseCategoryOption(option: $0)
        }
        if optionStrings.count != options.count {
            return nil
        }

        return AudioContext(
            category: category,
            options: options
        )
    }

    private static func parseCategory(category: String) throws -> AVAudioSession.Category? {
        switch category {
        case "ambient":
            return .ambient
        case "soloAmbient":
            return .soloAmbient
        case "playback":
            return .playback
        case "record":
            return .record
        case "playAndRecord":
            return .playAndRecord
        case "multiRoute":
            return .multiRoute
        default:
            throw AudioPlayerError.error("Invalid Category \(category)")
        }
    }

    private static func parseCategoryOption(option: String) throws -> AVAudioSession.CategoryOptions? {
        switch option {
        case "mixWithOthers":
            return .mixWithOthers
        case "duckOthers":
            return .duckOthers
        #if os(tvOS)
        case "allowBluetooth":
            if #available(tvOS 17.0, *) {
                return .allowBluetooth
            } else {
                throw AudioPlayerError.warning(
                    "Category Option allowBluetooth is only available on tvOS 17+")
            }
        case "allowBluetoothA2DP":
            if #available(tvOS 17.0, *) {
                return .allowBluetoothA2DP
            } else {
                throw AudioPlayerError.warning(
                    "Category Option allowBluetoothA2DP is only available on tvOS 17+")
            }
        #else
        case "allowBluetooth":
            return .allowBluetooth
        case "allowBluetoothA2DP":
            if #available(iOS 10.0, *) {
                return .allowBluetoothA2DP
            } else {
                throw AudioPlayerError.warning(
                    "Category Option allowBluetoothA2DP is only available on iOS 10+")
            }
        case "allowAirPlay":
            if #available(iOS 10.0, *) {
                return .allowAirPlay
            } else {
                throw AudioPlayerError.warning("Category Option allowAirPlay is only available on iOS 10+")
            }
        #endif
        case "defaultToSpeaker":
            #if !os(tvOS)
            return .defaultToSpeaker
            #else
            throw AudioPlayerError.warning("Category Option defaultToSpeaker is unavailable on tvOS")
            #endif
        case "interruptSpokenAudioAndMixWithOthers":
            return .interruptSpokenAudioAndMixWithOthers
        case "overrideMutedMicrophoneInterruption":
            #if !os(tvOS)
            if #available(iOS 14.5, *) {
                return .overrideMutedMicrophoneInterruption
            } else {
                throw AudioPlayerError.warning(
                    "Category Option overrideMutedMicrophoneInterruption is only available on iOS 14.5+")
            }
            #else
            throw AudioPlayerError.warning("Category Option overrideMutedMicrophoneInterruption is unavailable on tvOS")
            #endif
        default:
            throw AudioPlayerError.error("Invalid Category Option \(option)")
        }
    }
}
