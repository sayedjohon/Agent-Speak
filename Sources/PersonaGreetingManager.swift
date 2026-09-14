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

public class PersonaGreetingManager {
    public static let shared = PersonaGreetingManager()
    
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
    
    private init() {}
    
    public func getProfile(for tag: String) -> PersonaProfile? {
        if let direct = profiles[tag] { return direct }
        let normalized = tag.replacingOccurrences(of: "-", with: "_")
        return profiles[normalized]
    }
    
    public func resolveGreeting() -> (character: String, text: String) {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audio = json["audio"] as? [String: Any] else {
            return ("Mac System Voice", "Agent Speak is online and ready with your Mac System Voice.")
        }
        
        let engine = audio["engine"] as? String ?? "macos_default"
        if engine == "pocket_tts",
           let ptts = audio["pocket_tts"] as? [String: Any],
           let voiceTag = ptts["voice"] as? String {
            if let profile = getProfile(for: voiceTag) {
                return (profile.characterName, profile.greeting)
            } else {
                let clean = voiceTag.replacingOccurrences(of: "_", with: " ")
                return (clean, "\(clean) is online and ready at your service.")
            }
        } else {
            let macosVoice = audio["macos_voice"] as? String ?? "default"
            if macosVoice == "default" || macosVoice.isEmpty {
                return ("Mac System Voice", "Agent Speak is online and ready with your Mac System Voice.")
            } else {
                return (macosVoice, "Agent Speak is online and ready with \(macosVoice), your Mac System Voice.")
            }
        }
    }
}
