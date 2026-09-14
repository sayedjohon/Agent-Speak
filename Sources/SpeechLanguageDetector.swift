import Foundation
import AVFoundation
import NaturalLanguage

// MARK: - Multilingual Script Detector & Chunker
public enum ScriptType: Equatable {
    case bengali
    case devanagari
    case arabic
    case cjk
    case cyrillic
    case indicOther
    case thai
    case hebrew
    case greek
    case latin
    case common
}

public struct SpeechLanguageDetector {
    public static func scriptType(of char: Character) -> ScriptType {
        for scalar in char.unicodeScalars {
            let val = scalar.value
            // Common shared punctuation across Indic scripts (Danda । and Double Danda ॥)
            if val == 0x0964 || val == 0x0965 { return .common }
            
            // Bengali script (0x0980 - 0x09FF)
            if (0x0980...0x09FF).contains(val) { return .bengali }
            
            // Devanagari script (Hindi, Marathi, Nepali, Sanskrit: 0x0900 - 0x097F)
            if (0x0900...0x097F).contains(val) { return .devanagari }
            
            // Arabic / Urdu / Persian / Pashto
            if (0x0600...0x06FF).contains(val) || (0x0750...0x077F).contains(val) || (0x08A0...0x08FF).contains(val) || (0xFB50...0xFDFF).contains(val) || (0xFE70...0xFEFF).contains(val) {
                return .arabic
            }
            
            // CJK (Chinese, Japanese Kana, Korean Hangul)
            if (0x3040...0x30FF).contains(val) || (0x4E00...0x9FFF).contains(val) || (0x3400...0x4DBF).contains(val) || (0xAC00...0xD7AF).contains(val) || (0x1100...0x11FF).contains(val) {
                return .cjk
            }
            
            // Cyrillic (Russian, Ukrainian, etc.)
            if (0x0400...0x04FF).contains(val) || (0x0500...0x052F).contains(val) {
                return .cyrillic
            }
            
            // Other Indic scripts (Tamil, Telugu, Kannada, Malayalam, Gujarati, Gurmukhi)
            if (0x0B80...0x0BFF).contains(val) || (0x0C00...0x0C7F).contains(val) || (0x0C80...0x0CFF).contains(val) || (0x0D00...0x0D7F).contains(val) || (0x0A80...0x0AFF).contains(val) || (0x0A00...0x0A7F).contains(val) {
                return .indicOther
            }
            
            // Thai
            if (0x0E00...0x0E7F).contains(val) { return .thai }
            
            // Hebrew
            if (0x0590...0x05FF).contains(val) { return .hebrew }
            
            // Greek
            if (0x0370...0x03FF).contains(val) { return .greek }
            
            // Latin
            if (0x0041...0x005A).contains(val) || (0x0061...0x007A).contains(val) || (0x00C0...0x024F).contains(val) || (0x1E00...0x1EFF).contains(val) {
                return .latin
            }
        }
        return .common
    }
    
    public static func splitTextIntoChunks(text: String) -> [String] {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return [] }
        
        // 1. Sentence & phrase boundary split (including Bengali/Hindi Danda । and ॥)
        var rawSentences: [String] = []
        var cur = ""
        for char in clean {
            cur.append(char)
            if char == "." || char == "!" || char == "?" || char == "\n" || char == ":" || char == ";" || char == "।" || char == "॥" {
                let s = cur.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty && s.contains(where: { $0.isLetter || $0.isNumber }) {
                    rawSentences.append(s)
                }
                cur = ""
            }
        }
        let rem = cur.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rem.isEmpty && rem.contains(where: { $0.isLetter || $0.isNumber }) {
            rawSentences.append(rem)
        }
        if rawSentences.isEmpty {
            rawSentences = clean.contains(where: { $0.isLetter || $0.isNumber }) ? [clean] : []
        }
        
        // 2. Sub-segment mixed scripts (code-switching between Bengali, Hindi, English, etc.)
        var chunks: [String] = []
        for sentence in rawSentences {
            var segments: [String] = []
            var curScript: ScriptType = .common
            var buf = ""
            
            for char in sentence {
                let s = scriptType(of: char)
                if s == .common {
                    buf.append(char)
                } else if s == curScript {
                    buf.append(char)
                } else {
                    if curScript != .common && !buf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segments.append(buf.trimmingCharacters(in: .whitespacesAndNewlines))
                        buf = ""
                    }
                    curScript = s
                    buf.append(char)
                }
            }
            if !buf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(buf.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            let rawTargets = segments.isEmpty ? [sentence] : segments
            for target in rawTargets {
                let subSegments = subDivideOversizedSegment(target, maxWords: 18)
                for sub in subSegments {
                    var s = sub.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Clean leading punctuation that could confuse TTS models
                    while let first = s.first, first == "," || first == ";" || first == ":" || first == "-" || first == "—" || first == "." {
                        s.removeFirst()
                        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if !s.isEmpty && s.contains(where: { $0.isLetter || $0.isNumber }) {
                        chunks.append(s)
                    }
                }
            }
        }
        
        return chunks
    }
    
    /// Sub-divides sentences exceeding maxWords into natural clauses or phrase boundaries.
    /// Guarantees that Pocket-TTS never receives chunks over 40-50 tokens, eliminating word-skipping.
    private static func subDivideOversizedSegment(_ text: String, maxWords: Int = 18) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count <= maxWords {
            return [text]
        }
        
        // 1. Split on natural clause boundaries: commas, semicolons, em-dashes
        var clauses: [String] = []
        var cur = ""
        for char in text {
            cur.append(char)
            if char == "," || char == ";" || char == "—" || char == "–" {
                let s = cur.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty {
                    clauses.append(s)
                }
                cur = ""
            }
        }
        let rem = cur.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rem.isEmpty {
            clauses.append(rem)
        }
        
        var results: [String] = []
        var currentChunkWords: [String] = []
        
        for clause in clauses {
            let cWords = clause.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if currentChunkWords.count + cWords.count <= maxWords {
                currentChunkWords.append(contentsOf: cWords)
            } else {
                if !currentChunkWords.isEmpty {
                    results.append(currentChunkWords.joined(separator: " "))
                    currentChunkWords = []
                }
                if cWords.count <= maxWords {
                    currentChunkWords.append(contentsOf: cWords)
                } else {
                    // Clause itself exceeds maxWords: split on coordinating conjunctions or word count
                    var sub = cWords
                    let conjunctions: Set<String> = [
                        "and", "but", "or", "so", "because", "although", "however",
                        "which", "that", "with", "without", "when", "while", "where", "if"
                    ]
                    while sub.count > maxWords {
                        var splitIdx = maxWords
                        for i in stride(from: min(sub.count - 1, maxWords), through: 8, by: -1) {
                            let w = sub[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
                            if conjunctions.contains(w) {
                                splitIdx = i
                                break
                            }
                        }
                        let head = sub.prefix(splitIdx).joined(separator: " ")
                        results.append(head)
                        sub = Array(sub.dropFirst(splitIdx))
                    }
                    if !sub.isEmpty {
                        currentChunkWords.append(contentsOf: sub)
                    }
                }
            }
        }
        
        if !currentChunkWords.isEmpty {
            results.append(currentChunkWords.joined(separator: " "))
        }
        
        return results.isEmpty ? [text] : results
    }

    
    /// Determines whether Pocket-TTS can synthesize this text chunk.
    /// Pocket-TTS uses an English neural model. Any non-English or non-Latin script
    /// (Bengali, Hindi, Arabic, Chinese, Russian, etc.) is not supported and will fail.
    public static func isPocketTTSSupported(text: String, documentLanguage: String) -> Bool {
        // Any non-Latin script characters immediately disqualify from Pocket-TTS
        for scalar in text.unicodeScalars {
            let val = scalar.value
            if val == 0x0964 || val == 0x0965 { continue } // danda punctuation
            // Bengali
            if (0x0980...0x09FF).contains(val) { return false }
            // Devanagari (Hindi)
            if (0x0900...0x097F).contains(val) { return false }
            // Arabic / Urdu / Persian
            if (0x0600...0x06FF).contains(val) || (0x0750...0x077F).contains(val) || (0x08A0...0x08FF).contains(val) || (0xFB50...0xFDFF).contains(val) || (0xFE70...0xFEFF).contains(val) { return false }
            // CJK
            if (0x3040...0x30FF).contains(val) || (0x4E00...0x9FFF).contains(val) || (0x3400...0x4DBF).contains(val) || (0xAC00...0xD7AF).contains(val) || (0x1100...0x11FF).contains(val) { return false }
            // Cyrillic
            if (0x0400...0x04FF).contains(val) || (0x0500...0x052F).contains(val) { return false }
            // Indic Other
            if (0x0B80...0x0D7F).contains(val) || (0x0A00...0x0AFF).contains(val) { return false }
            // Thai, Hebrew, Greek
            if (0x0E00...0x0E7F).contains(val) || (0x0590...0x05FF).contains(val) || (0x0370...0x03FF).contains(val) { return false }
        }
        
        // If the document as a whole is identified as a non-English language (e.g. French, Spanish)
        if !documentLanguage.starts(with: "en") && documentLanguage != "und" {
            return false
        }
        
        // For substantial Latin text, test if it is a non-English language
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 25 {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(trimmed)
            if let (lang, prob) = recognizer.languageHypotheses(withMaximum: 1).first,
               prob > 0.85,
               !lang.rawValue.starts(with: "en") && lang.rawValue != "und" {
                return false
            }
        }
        
        return true
    }
    
    /// Resolves the optimal macOS native voice for a given chunk of text.
    public static func resolveNativeVoice(
        for text: String,
        documentLanguage: String,
        macosVoice: String,
        pocketVoice: String,
        engine: String
    ) -> String? {
        var hasBengali = false
        var hasDevanagari = false
        var hasArabic = false
        var hasJapaneseKana = false
        var hasKorean = false
        var hasHanIdeograph = false
        var hasCyrillic = false
        var hasTamil = false
        var hasTelugu = false
        var hasKannada = false
        var hasMalayalam = false
        var hasGujarati = false
        var hasGurmukhi = false
        var hasThai = false
        var hasHebrew = false
        var hasGreek = false
        
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if v == 0x0964 || v == 0x0965 { continue }
            if (0x0980...0x09FF).contains(v) { hasBengali = true; break }
            else if (0x0900...0x097F).contains(v) { hasDevanagari = true; break }
            else if (0x0600...0x06FF).contains(v) || (0x0750...0x077F).contains(v) || (0x08A0...0x08FF).contains(v) || (0xFB50...0xFDFF).contains(v) || (0xFE70...0xFEFF).contains(v) { hasArabic = true; break }
            else if (0x3040...0x30FF).contains(v) { hasJapaneseKana = true }
            else if (0xAC00...0xD7AF).contains(v) || (0x1100...0x11FF).contains(v) { hasKorean = true; break }
            else if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) { hasHanIdeograph = true }
            else if (0x0400...0x04FF).contains(v) || (0x0500...0x052F).contains(v) { hasCyrillic = true; break }
            else if (0x0B80...0x0BFF).contains(v) { hasTamil = true; break }
            else if (0x0C00...0x0C7F).contains(v) { hasTelugu = true; break }
            else if (0x0C80...0x0CFF).contains(v) { hasKannada = true; break }
            else if (0x0D00...0x0D7F).contains(v) { hasMalayalam = true; break }
            else if (0x0A80...0x0AFF).contains(v) { hasGujarati = true; break }
            else if (0x0A00...0x0A7F).contains(v) { hasGurmukhi = true; break }
            else if (0x0E00...0x0E7F).contains(v) { hasThai = true; break }
            else if (0x0590...0x05FF).contains(v) { hasHebrew = true; break }
            else if (0x0370...0x03FF).contains(v) { hasGreek = true; break }
        }
        
        // 1. Script-specific native voice mapping
        if hasBengali {
            return AVSpeechSynthesisVoice(language: "bn-IN")?.name ?? "Piya"
        }
        if hasDevanagari {
            return AVSpeechSynthesisVoice(language: "hi-IN")?.name ?? "Lekha"
        }
        if hasArabic {
            return AVSpeechSynthesisVoice(language: "ar-001")?.name ?? AVSpeechSynthesisVoice(language: "ar-SA")?.name ?? "Majed"
        }
        if hasJapaneseKana {
            return AVSpeechSynthesisVoice(language: "ja-JP")?.name ?? "Kyoko"
        }
        if hasKorean {
            return AVSpeechSynthesisVoice(language: "ko-KR")?.name ?? "Yuna"
        }
        if hasHanIdeograph {
            return AVSpeechSynthesisVoice(language: "zh-CN")?.name ?? "Tingting"
        }
        if hasCyrillic {
            return AVSpeechSynthesisVoice(language: "ru-RU")?.name ?? "Milena"
        }
        if hasTamil {
            return AVSpeechSynthesisVoice(language: "ta-IN")?.name ?? "Vani"
        }
        if hasTelugu {
            return AVSpeechSynthesisVoice(language: "te-IN")?.name ?? "Geeta"
        }
        if hasKannada {
            return AVSpeechSynthesisVoice(language: "kn-IN")?.name ?? "Soumya"
        }
        if hasMalayalam {
            return AVSpeechSynthesisVoice(language: "ml-IN")?.name
        }
        if hasGujarati {
            return AVSpeechSynthesisVoice(language: "gu-IN")?.name
        }
        if hasGurmukhi {
            return AVSpeechSynthesisVoice(language: "pa-IN")?.name
        }
        if hasThai {
            return AVSpeechSynthesisVoice(language: "th-TH")?.name ?? "Kanya"
        }
        if hasHebrew {
            return AVSpeechSynthesisVoice(language: "he-IL")?.name ?? "Carmit"
        }
        if hasGreek {
            return AVSpeechSynthesisVoice(language: "el-GR")?.name ?? "Melina"
        }
        
        // 2. Latin / general document language check
        if !documentLanguage.starts(with: "en") && documentLanguage != "und" {
            if let match = AVSpeechSynthesisVoice(language: documentLanguage) {
                return match.name
            }
        }
        
        // 3. Chunk-level language detection for Latin scripts (e.g. Spanish, French, German)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 20 {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(trimmed)
            if let (lang, prob) = recognizer.languageHypotheses(withMaximum: 1).first,
               prob > 0.85,
               !lang.rawValue.starts(with: "en") && lang.rawValue != "und" {
                if let matchVoice = AVSpeechSynthesisVoice(language: lang.rawValue) {
                    return matchVoice.name
                }
            }
        }
        
        // 4. English fallback
        if macosVoice != "default" && !macosVoice.isEmpty {
            return macosVoice
        }
        if engine == "pocket_tts" && (pocketVoice.contains("Jarvis") || pocketVoice == "Daniel") {
            return "Daniel"
        }
        
        return nil
    }
}
