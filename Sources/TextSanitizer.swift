import Foundation

public struct TextSanitizer {
    public static var speakCodeBlocks: Bool = false
    
    public static func sanitizeForSpeech(_ text: String, speakCodeBlocks customSpeakCode: Bool? = nil) -> String {
        let shouldSpeakCode = customSpeakCode ?? speakCodeBlocks
        var str = text
        
        // 0. Remove any system truncation markers (prevents artificial cuts and spoken token artifacts)
        str = replaceRegex(str, pattern: "<truncated \\d+ bytes>", with: "")
        
        if !shouldSpeakCode {
            // 1. Default: Strip paired fenced code blocks ```...```
            str = replaceRegex(str, pattern: "```[\\s\\S]*?```", with: "")
            
            // 2. If an unclosed ``` exists, strip code content without discarding subsequent conversational paragraphs
            if str.contains("```") {
                str = replaceRegex(str, pattern: "```[a-zA-Z0-9_-]*\\n[\\s\\S]*?(?=\\n\\s*\\n\\s*[A-Za-z#*\\-\\d]|$)", with: "")
                str = replaceRegex(str, pattern: "^\\s*```.*$", with: "", options: [.anchorsMatchLines])
            }
        } else {
            // 1. Speak Everything Enabled: Retain code block contents, but strip fences and sanitize syntax for spoken speech
            // Remove opening fence line with optional language identifier (e.g. ```python, ```bash, ```json, ```markdown)
            str = replaceRegex(str, pattern: "```[a-zA-Z0-9_\\-\\+]*\\n?", with: "\n")
            // Remove closing/remaining code fences
            str = replaceRegex(str, pattern: "```", with: "")
            
            // 2. Remove decorative banner/separator lines (e.g. #########, // =======, ---------)
            str = replaceRegex(str, pattern: "^\\s*[#\\/\\*\\-=_]{3,}\\s*$", with: "", options: [.anchorsMatchLines])
            
            // 3. Clean line-starting comment markers and markdown headings (# or //)
            // Eliminates "hashtag hashtag" or "slash slash" entirely
            str = replaceRegex(str, pattern: "^\\s*#+\\s*", with: "", options: [.anchorsMatchLines])
            str = replaceRegex(str, pattern: "^\\s*\\/{2,}\\s*", with: "", options: [.anchorsMatchLines])
            
            // 4. Clean trailing heading hashes (e.g. ## Title ## -> Title)
            str = replaceRegex(str, pattern: "\\s*#+\\s*$", with: "", options: [.anchorsMatchLines])
            
            // 5. Clean inline comment markers (e.g. count += 1 # counter)
            str = replaceRegex(str, pattern: "\\s+#+\\s*", with: " ")
            str = replaceRegex(str, pattern: "\\s+\\/{2,}\\s*", with: " ")
            
            // 6. Clean block comment delimiters (/* and */)
            str = replaceRegex(str, pattern: "\\/\\*|\\*\\/", with: "")
            
            // 7. Strip lines that only contain structural braces/brackets/semicolons/commas
            str = replaceRegex(str, pattern: "^\\s*[\\{\\}\\[\\]\\(\\);,]+\\s*$", with: "", options: [.anchorsMatchLines])
            
            // 8. Strip trailing semicolons at line ends
            str = replaceRegex(str, pattern: ";\\s*$", with: "", options: [.anchorsMatchLines])
            
            // 9. Convert programming operators to conversational words
            str = str.replacingOccurrences(of: "!==", with: " is not identical to ")
            str = str.replacingOccurrences(of: "===", with: " is identical to ")
            str = str.replacingOccurrences(of: "!=", with: " is not equal to ")
            str = str.replacingOccurrences(of: "==", with: " equals ")
            str = str.replacingOccurrences(of: "<=", with: " less than or equal to ")
            str = str.replacingOccurrences(of: ">=", with: " greater than or equal to ")
            str = str.replacingOccurrences(of: "&&", with: " and ")
            str = str.replacingOccurrences(of: "||", with: " or ")
            str = str.replacingOccurrences(of: "+=", with: " plus equals ")
            str = str.replacingOccurrences(of: "-=", with: " minus equals ")
            str = str.replacingOccurrences(of: "*=", with: " times equals ")
            str = str.replacingOccurrences(of: "/=", with: " divided by equals ")
        }
        
        // 2. Strip inline code `...`
        str = replaceRegex(str, pattern: "`([^`]+)`", with: "$1")
        str = replaceRegex(str, pattern: "`", with: "")
        
        // 3. Convert snake_case identifier underscores into natural spaces (e.g. get_discount -> get discount)
        str = replaceRegex(str, pattern: "(?<=[a-zA-Z0-9])_(?=[a-zA-Z0-9])", with: " ")
        
        // 4. Strip emojis & pictorial symbols (without stripping ASCII digits)
        str = replaceRegex(str, pattern: "[\\p{Extended_Pictographic}\\p{EMOJI_MODIFIER}]", with: "")
        
        // 5. Strip images ![alt](url)
        str = replaceRegex(str, pattern: "!\\[.*?\\]\\(.*?\\)", with: "")
        
        // 6. Convert markdown links [Label](url) -> Label
        str = replaceRegex(str, pattern: "\\[(.*?)\\]\\([^\\)]*\\)", with: "$1")
        
        // 7. Strip raw URLs
        str = replaceRegex(str, pattern: "https?://\\S+", with: "")
        
        // 8. Strip markdown table syntax (| col | col |)
        str = replaceRegex(str, pattern: "^\\s*\\|.*\\|\\s*$", with: "", options: [.anchorsMatchLines])
        str = replaceRegex(str, pattern: "^[|\\-:\\s]+$", with: "", options: [.anchorsMatchLines])
        
        // 9. Strip markdown headings (# Title) - handles any number of hashes and optional leading whitespace
        str = replaceRegex(str, pattern: "^\\s*#{1,6}\\s*", with: "", options: [.anchorsMatchLines])
        
        // 10. Strip blockquotes (> Quote)
        str = replaceRegex(str, pattern: "^\\s*>\\s*(\\[!NOTE\\]|\\[!TIP\\]|\\[!IMPORTANT\\]|\\[!WARNING\\]|\\[!CAUTION\\])?", with: "", options: [.anchorsMatchLines])
        
        // 11. Strip bold, italic, strikethrough (*, _, ~)
        str = replaceRegex(str, pattern: "[\\*_~]{1,3}", with: "")
        
        // 12. Strip horizontal divider rules (---, ***, ___)
        str = replaceRegex(str, pattern: "^\\s*[-*_]{3,}\\s*$", with: "", options: [.anchorsMatchLines])
        
        // 13. Strip HTML/XML tags
        str = replaceRegex(str, pattern: "<[^>]+>", with: "")
        
        // 14. Clean list bullets and numbering for conversational flow
        str = replaceRegex(str, pattern: "^\\s*[\\*\\-\\+•⁃‣]\\s+", with: "", options: [.anchorsMatchLines])
        str = replaceRegex(str, pattern: "^\\s*\\d+\\.\\s+", with: "", options: [.anchorsMatchLines])
        
        // 15. Convert symbols to spoken words
        str = str.replacingOccurrences(of: "->", with: " to ")
        str = str.replacingOccurrences(of: "=>", with: " leads to ")
        str = str.replacingOccurrences(of: "&", with: " and ")
        str = str.replacingOccurrences(of: "@", with: " at ")
        str = str.replacingOccurrences(of: "%", with: " percent ")
        
        // 16. Scrub any remaining stray hash symbols anywhere so TTS NEVER utters "hashtag"
        str = replaceRegex(str, pattern: "#+", with: "")
        
        // 17. Normalize whitespace
        str = replaceRegex(str, pattern: "[ \\t]+", with: " ")
        str = replaceRegex(str, pattern: "\\n{2,}", with: "\n")
        
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func replaceRegex(_ string: String, pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return string }
        let range = NSRange(location: 0, length: (string as NSString).length)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: replacement)
    }
}
