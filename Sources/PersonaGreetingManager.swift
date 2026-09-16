import Foundation

public struct PersonaProfile {
    public let tag: String
    public let characterName: String
    public let gender: String
    public let subtitle: String
    public let greeting: String
    
    public init(tag: String, characterName: String, gender: String, subtitle: String, greeting: String) {
        self.tag = tag
        self.characterName = characterName
        self.gender = gender
        self.subtitle = subtitle
        self.greeting = greeting
    }
}

// MARK: - Greeting Category Model
public struct GreetingCategoryItem: Identifiable, Hashable {
    public var id: String { tag }
    public let tag: String
    public let displayName: String
    public let icon: String
    public let subtitle: String
    
    public init(tag: String, displayName: String, icon: String, subtitle: String) {
        self.tag = tag
        self.displayName = displayName
        self.icon = icon
        self.subtitle = subtitle
    }
}

public class PersonaGreetingManager: ObservableObject {
    public static let shared = PersonaGreetingManager()
    
    // MARK: - User & Assistant Profile Settings
    @Published public var userName: String = "Johon"
    @Published public var agentName: String = "Jarvis"
    @Published public var greetingMode: String = "dynamic" // "dynamic" or "custom"
    @Published public var greetingCategory: String = "all" // "all", "jarvis", "friendly", "direct", "copilot", "energetic"
    @Published public var customStartupText: String = "Good day Johon, Jarvis is ready at your service."
    @Published public var speakOnStartup: Bool = true
    
    private var lastGreetingIndex: Int = -1
    
    public let profiles: [String: PersonaProfile] = [
        "Jarvis_Best": PersonaProfile(
            tag: "Jarvis_Best",
            characterName: "Jarvis",
            gender: "Male",
            subtitle: "AI Butler (Authoritative British - Primary)",
            greeting: "Jarvis is here at your service, sir. All systems are operational."
        ),
        "Jarvis": PersonaProfile(
            tag: "Jarvis",
            characterName: "Jarvis",
            gender: "Male",
            subtitle: "AI Butler (Authoritative British Classic)",
            greeting: "Jarvis is at your service, sir. Ready for your instructions."
        ),
        "Sayed_Johon_Primary": PersonaProfile(
            tag: "Sayed_Johon_Primary",
            characterName: "Johon",
            gender: "Male",
            subtitle: "Creator Clone (Studio Clarity)",
            greeting: "Johon is online and ready at your service."
        ),
        "Male_Peace": PersonaProfile(
            tag: "Male_Peace",
            characterName: "Oliver",
            gender: "Male",
            subtitle: "Calm & Meditative Voice",
            greeting: "Oliver is online, calm and ready whenever you need."
        ),
        "Male_News_Caster": PersonaProfile(
            tag: "Male_News_Caster",
            characterName: "Marcus",
            gender: "Male",
            subtitle: "Deep Social Media News Anchor",
            greeting: "This is Marcus, ready to deliver your news and updates."
        ),
        "Female_Soft_Intimate": PersonaProfile(
            tag: "Female_Soft_Intimate",
            characterName: "Emma",
            gender: "Female",
            subtitle: "Gentle & Warm Conversationalist",
            greeting: "Emma is here and ready to assist you."
        ),
        "Female_Podcast_Host": PersonaProfile(
            tag: "Female_Podcast_Host",
            characterName: "Chloe",
            gender: "Female",
            subtitle: "Engaging Conversational Host",
            greeting: "Chloe is on the mic and ready for action."
        ),
        "Male_American_Narrator": PersonaProfile(
            tag: "Male_American_Narrator",
            characterName: "Ethan",
            gender: "Male",
            subtitle: "Casual Conversational Narrator",
            greeting: "Ethan is here, ready to narrate your next session."
        ),
        "Male_Shorts_Creator": PersonaProfile(
            tag: "Male_Shorts_Creator",
            characterName: "Leo",
            gender: "Male",
            subtitle: "High-Energy YouTube Shorts Creator",
            greeting: "Leo is here, let's create something viral."
        ),
        "Male_Viral_Actor": PersonaProfile(
            tag: "Male_Viral_Actor",
            characterName: "Zach",
            gender: "Male",
            subtitle: "Viral Dynamic Content Creator",
            greeting: "Zach is locked and loaded, ready to roll."
        ),
        "Female_Confident_Sultry": PersonaProfile(
            tag: "Female_Confident_Sultry",
            characterName: "Sophia",
            gender: "Female",
            subtitle: "Confident, Sly & Expressive",
            greeting: "Sophia is online and ready for you."
        ),
        "Male_Energetic_Creator": PersonaProfile(
            tag: "Male_Energetic_Creator",
            characterName: "Alex",
            gender: "Male",
            subtitle: "Upbeat Social Media Storyteller",
            greeting: "Alex is hyped and ready to go."
        ),
        "Male_Social_Media": PersonaProfile(
            tag: "Male_Social_Media",
            characterName: "Noah",
            gender: "Male",
            subtitle: "Modern Social Media Presenter",
            greeting: "Noah is connected and ready to broadcast."
        ),
        "Male_New": PersonaProfile(
            tag: "Male_New",
            characterName: "Lucas",
            gender: "Male",
            subtitle: "Crisp Modern Tone",
            greeting: "Lucas is standing by and ready."
        ),
        "Female_New": PersonaProfile(
            tag: "Female_New",
            characterName: "Ava",
            gender: "Female",
            subtitle: "Fresh Modern Tone",
            greeting: "Ava is here and ready to speak."
        ),
        "Male_Old_Storyteller": PersonaProfile(
            tag: "Male_Old_Storyteller",
            characterName: "Arthur",
            gender: "Male",
            subtitle: "Seasoned Warm Storyteller",
            greeting: "Arthur is here, ready to tell your stories."
        ),
        "Female_Aah": PersonaProfile(
            tag: "Female_Aah",
            characterName: "Mia",
            gender: "Female",
            subtitle: "Expressive & Soulful",
            greeting: "Mia is here, ready whenever you are."
        ),
        "Female_Pro_2": PersonaProfile(
            tag: "Female_Pro_2",
            characterName: "Elena",
            gender: "Female",
            subtitle: "Polished Professional Narrator",
            greeting: "Elena is at your service, ready to assist."
        ),
        "Male_Adam_v2": PersonaProfile(
            tag: "Male_Adam_v2",
            characterName: "Adam",
            gender: "Male",
            subtitle: "Natural Studio Clarity",
            greeting: "Adam is online and standing by."
        ),
        "alba": PersonaProfile(
            tag: "alba",
            characterName: "Alba",
            gender: "Female",
            subtitle: "Natural Scottish Storyteller",
            greeting: "Alba is online and ready to assist."
        ),
        "george": PersonaProfile(
            tag: "george",
            characterName: "George",
            gender: "Male",
            subtitle: "Deep British Narrator",
            greeting: "George is at your service, ready to assist."
        ),
        "cosette": PersonaProfile(
            tag: "cosette",
            characterName: "Cosette",
            gender: "Female",
            subtitle: "Warm & Expressive",
            greeting: "Cosette is ready to speak."
        ),
        "marius": PersonaProfile(
            tag: "marius",
            characterName: "Marius",
            gender: "Male",
            subtitle: "Casual Conversationalist",
            greeting: "Marius is here and standing by."
        )
    ]
    
    // MARK: - Persona & Tone Categories
    public let availableCategories: [GreetingCategoryItem] = [
        GreetingCategoryItem(tag: "all", displayName: "🎲 All Styles (Auto-Rotate)", icon: "sparkles.rectangle.stack.fill", subtitle: "Dynamically rotates across every persona"),
        GreetingCategoryItem(tag: "jarvis", displayName: "🛡️ Iron Man J.A.R.V.I.S.", icon: "shield.checkered", subtitle: "Authentic British AI butler addressing you as Sir"),
        GreetingCategoryItem(tag: "friendly", displayName: "☀️ Warm & Friendly", icon: "sun.max.fill", subtitle: "Cheerful, welcoming, and relaxed companion"),
        GreetingCategoryItem(tag: "direct", displayName: "⚡️ Direct & Minimal", icon: "bolt.horizontal.fill", subtitle: "Concise, focused, and straight to the point"),
        GreetingCategoryItem(tag: "copilot", displayName: "💻 Coding Co-Pilot", icon: "chevron.left.forwardslash.chevron.right", subtitle: "Developer peer ready for building and debugging"),
        GreetingCategoryItem(tag: "energetic", displayName: "🔥 Hype & Motivational", icon: "flame.fill", subtitle: "Upbeat energy to kickstart your productivity")
    ]
    
    // 1. Authentic Iron Man J.A.R.V.I.S. (Addresses user as "sir")
    public let jarvisGreetings: [String] = [
        "Good day, sir. All core protocols are online and awaiting your instructions.",
        "JARVIS at your service, sir. All diagnostic telemetry is nominal.",
        "Always a pleasure watching you work, sir. Standing by.",
        "Power levels steady, diagnostics green, sir. Ready when you are.",
        "Good to see you, sir. How may I assist your mission today?",
        "Awaiting your parameters, sir. Everything is calibrated and prepared.",
        "Right beside you, sir. Ready to run diagnostics or crunch code.",
        "JARVIS reporting in, sir. Workspace conduits are active.",
        "Welcome back to the workshop, sir. Let us see what we can create today.",
        "At your disposal as always, sir. What is our first objective?",
        "We are completely operational, sir. Standing by for your command.",
        "Good to have you back at the console, sir. All systems are green."
    ]
    
    // 2. Warm & Friendly Companion
    public let friendlyGreetings: [String] = [
        "Hey {user}, {agent} is here and ready to help!",
        "Hi {user}! Good to see you today.",
        "Welcome back, {user}! I am ready whenever you are.",
        "Hey {user}! Hope you are having a wonderful day.",
        "Hello {user}! Your friend {agent} is right here.",
        "Hey {user}! Nice to see you. What are we doing today?",
        "Good to have you here, {user}! I am all ready.",
        "Hi {user}! Great to hear from you. Let's dive right in."
    ]
    
    // 3. Direct & Minimal Assistant
    public let directGreetings: [String] = [
        "All systems ready. Standing by for instructions, {user}.",
        "Hi {user}! Ready when you are.",
        "Hey {user}! All set up and good to go.",
        "Hello {user}! I am listening and ready.",
        "Welcome back, {user}! Standing by for your tasks.",
        "Ready to assist, {user}. What is our first step?",
        "Audio conduits active. Ready when you are, {user}.",
        "Connected and listening, {user}."
    ]
    
    // 4. Coding & Creative Co-Pilot
    public let copilotGreetings: [String] = [
        "Hey {user}! Let's write some great code together.",
        "Welcome back {user}! Let's build something awesome today.",
        "Hey {user}! Ready to read and speak whenever you need.",
        "Hi {user}! {agent} is right here at your side.",
        "Hey {user}! What are we building or debugging today?",
        "Console is clear, {user}. Let's make something amazing.",
        "Ready to pair program with you, {user}. Let's go!",
        "Workspace linked. Let's do some great work today, {user}."
    ]
    
    // 5. Energetic & Motivational
    public let energeticGreetings: [String] = [
        "Hey {user}! It is a brand new session, let's do this!",
        "Hi {user}! You are doing great today. Let's go!",
        "Hey {user}! Let's make today a super productive day.",
        "Time to create something amazing, {user}! Let's roll.",
        "Hey {user}! Let's knock out some big goals today!",
        "Hyped and ready to roll, {user}! What is first on deck?",
        "Big energy today, {user}! Let's make it count!",
        "Hello {user}! Ready to crush whatever comes next!"
    ]
    
    // Concatenated pool for All Styles
    public var dynamicGreetings: [String] {
        jarvisGreetings + friendlyGreetings + directGreetings + copilotGreetings + energeticGreetings
    }
    
    private var isConfigLoaded: Bool = false
    
    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
    }
    
    private init() {
        loadConfiguration(force: true)
    }
    
    public func getProfile(for tag: String) -> PersonaProfile? {
        if let direct = profiles[tag] { return direct }
        let normalized = tag.replacingOccurrences(of: "-", with: "_")
        return profiles[normalized]
    }
    
    // MARK: - Pool Selection by Category
    public func getPool(for category: String? = nil) -> [String] {
        let cat = category ?? greetingCategory
        switch cat {
        case "jarvis":
            return jarvisGreetings
        case "friendly":
            return friendlyGreetings
        case "direct":
            return directGreetings
        case "copilot":
            return copilotGreetings
        case "energetic":
            return energeticGreetings
        default: // "all"
            return dynamicGreetings
        }
    }
    
    // MARK: - Configuration I/O
    public func loadConfiguration(force: Bool = false) {
        if isConfigLoaded && !force { return }
        isConfigLoaded = true
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        if let profile = json["user_profile"] as? [String: Any] {
            if let u = profile["user_name"] as? String, !u.isEmpty {
                self.userName = u
            }
            if let a = profile["agent_name"] as? String, !a.isEmpty {
                self.agentName = a
            }
            if let m = profile["greeting_mode"] as? String, !m.isEmpty {
                self.greetingMode = m
            }
            if let cat = profile["greeting_category"] as? String, !cat.isEmpty {
                self.greetingCategory = cat
            }
            if let c = profile["custom_startup_text"] as? String {
                self.customStartupText = c
            }
            if let s = profile["speak_on_startup"] as? Bool {
                self.speakOnStartup = s
            }
        }
    }
    
    public func saveConfiguration() {
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var profile = json["user_profile"] as? [String: Any] ?? [:]
        profile["user_name"] = userName
        profile["agent_name"] = agentName
        profile["greeting_mode"] = greetingMode
        profile["greeting_category"] = greetingCategory
        profile["custom_startup_text"] = customStartupText
        profile["speak_on_startup"] = speakOnStartup
        json["user_profile"] = profile
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: configURL)
        }
    }
    
    public func updateProfile(
        userName: String,
        agentName: String,
        greetingMode: String,
        greetingCategory: String = "all",
        customStartupText: String,
        speakOnStartup: Bool
    ) {
        self.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Johon" : userName
        self.agentName = agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : agentName
        self.greetingMode = greetingMode
        self.greetingCategory = greetingCategory
        self.customStartupText = customStartupText
        self.speakOnStartup = speakOnStartup
        self.isConfigLoaded = true
        saveConfiguration()
    }
    
    // MARK: - Greeting Formatting & Random Selection
    public func formatGreeting(_ template: String, user: String, agent: String) -> String {
        let resolvedUser = user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Johon" : user.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAgent = agent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : agent.trimmingCharacters(in: .whitespacesAndNewlines)
        return template
            .replacingOccurrences(of: "{user}", with: resolvedUser)
            .replacingOccurrences(of: "{User}", with: resolvedUser)
            .replacingOccurrences(of: "{name}", with: resolvedUser)
            .replacingOccurrences(of: "{Name}", with: resolvedUser)
            .replacingOccurrences(of: "{agent}", with: resolvedAgent)
            .replacingOccurrences(of: "{Agent}", with: resolvedAgent)
    }
    
    public func getRandomGreetingTemplate(for category: String? = nil) -> String {
        let pool = getPool(for: category)
        guard !pool.isEmpty else { return "Hey {user}, {agent} is ready to help!" }
        if pool.count == 1 { return pool[0] }
        var nextIdx = Int.random(in: 0..<pool.count)
        while nextIdx == lastGreetingIndex {
            nextIdx = Int.random(in: 0..<pool.count)
        }
        lastGreetingIndex = nextIdx
        return pool[nextIdx]
    }
    
    public func previewSample(for category: String? = nil, template: String? = nil) -> String {
        let effAgent = agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : agentName
        if greetingMode == "custom" && !customStartupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return formatGreeting(customStartupText, user: userName, agent: effAgent)
        }
        let targetCategory = category ?? greetingCategory
        let tmpl = template ?? getRandomGreetingTemplate(for: targetCategory)
        return formatGreeting(tmpl, user: userName, agent: effAgent)
    }
    
    // MARK: - Greeting Resolution Engine
    public func resolveGreeting(forVoice voiceTag: String? = nil, engine: String? = nil) -> (character: String, text: String) {
        loadConfiguration(force: false)
        
        let configPath = configURL
        let resolvedEngine: String
        let resolvedVoice: String
        
        if let data = try? Data(contentsOf: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let audio = json["audio"] as? [String: Any] {
            resolvedEngine = engine ?? (audio["engine"] as? String ?? "macos_default")
            if resolvedEngine == "pocket_tts",
               let ptts = audio["pocket_tts"] as? [String: Any],
               let v = ptts["voice"] as? String {
                resolvedVoice = voiceTag ?? v
            } else {
                resolvedVoice = voiceTag ?? (audio["macos_voice"] as? String ?? "default")
            }
        } else {
            resolvedEngine = engine ?? "macos_default"
            resolvedVoice = voiceTag ?? "default"
        }
        
        let effectiveAgent: String
        if resolvedEngine == "pocket_tts" {
            if let profile = getProfile(for: resolvedVoice) {
                effectiveAgent = (agentName == "Jarvis" || agentName.isEmpty) ? profile.characterName : agentName
            } else {
                let clean = resolvedVoice.replacingOccurrences(of: "_", with: " ")
                effectiveAgent = (agentName == "Jarvis" || agentName.isEmpty) ? clean : agentName
            }
        } else {
            effectiveAgent = agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : agentName
        }
        
        if greetingMode == "custom" && !customStartupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let formatted = formatGreeting(customStartupText, user: userName, agent: effectiveAgent)
            return (effectiveAgent, formatted)
        }
        
        let template = getRandomGreetingTemplate(for: greetingCategory)
        let formatted = formatGreeting(template, user: userName, agent: effectiveAgent)
        return (effectiveAgent, formatted)
    }
    
    public func resolveVoiceSwitchGreeting(voiceName: String, characterName: String? = nil) -> (character: String, text: String) {
        loadConfiguration(force: false)
        let effectiveAgent = characterName ?? (agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : agentName)
        let template = getRandomGreetingTemplate(for: greetingCategory)
        let formatted = formatGreeting(template, user: userName, agent: effectiveAgent)
        return (effectiveAgent, formatted)
    }
}
