import Foundation

public struct TextSanitizer {
    public static func sanitizeForSpeech(_ text: String) -> String {
        var str = text
        
        // 1. Strip fenced code blocks ```...```
        str = replaceRegex(str, pattern: "```[\\s\\S]*?```", with: "")
        
        // 2. Strip inline code `...`
        str = replaceRegex(str, pattern: "`([^`]+)`", with: "$1")
        
        // 3. Strip images ![alt](url)
        str = replaceRegex(str, pattern: "!\\[.*?\\]\\(.*?\\)", with: "")
        
        // 4. Convert markdown links [Label](url) -> Label
        str = replaceRegex(str, pattern: "\\[(.*?)\\]\\([^\\)]*\\)", with: "$1")
        
        // 5. Strip raw URLs
        str = replaceRegex(str, pattern: "https?://\\S+", with: "")
        
        // 6. Strip markdown table syntax (| col | col |)
        str = replaceRegex(str, pattern: "\\|.*\\|", with: "")
        str = replaceRegex(str, pattern: "^[|\\-:\\s]+$", with: "", options: [.anchorsMatchLines])
        
        // 7. Strip markdown headings (# Title)
        str = replaceRegex(str, pattern: "^\\s*#{1,6}\\s+", with: "", options: [.anchorsMatchLines])
        
        // 8. Strip blockquotes (> Quote)
        str = replaceRegex(str, pattern: "^\\s*>\\s*(\\[!NOTE\\]|\\[!TIP\\]|\\[!IMPORTANT\\]|\\[!WARNING\\]|\\[!CAUTION\\])?", with: "", options: [.anchorsMatchLines])
        
        // 9. Strip bold, italic, strikethrough (*, _, ~)
        str = replaceRegex(str, pattern: "[\\*_~]{1,3}", with: "")
        
        // 10. Strip horizontal divider rules (---, ***, ___)
        str = replaceRegex(str, pattern: "^\\s*[-*_]{3,}\\s*$", with: "", options: [.anchorsMatchLines])
        
        // 11. Strip HTML/XML tags
        str = replaceRegex(str, pattern: "<[^>]+>", with: "")
        
        // 12. Clean list bullets and numbering for conversational flow
        str = replaceRegex(str, pattern: "^\\s*[\\*\\-\\+]\\s+", with: "", options: [.anchorsMatchLines])
        str = replaceRegex(str, pattern: "^\\s*\\d+\\.\\s+", with: "", options: [.anchorsMatchLines])
        
        // 13. Convert symbols to spoken words
        str = str.replacingOccurrences(of: "->", with: " to ")
        str = str.replacingOccurrences(of: "=>", with: " leads to ")
        str = str.replacingOccurrences(of: "&", with: " and ")
        str = str.replacingOccurrences(of: "@", with: " at ")
        str = str.replacingOccurrences(of: "%", with: " percent ")
        
        // 14. Normalize whitespace
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
