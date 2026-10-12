import Foundation

enum VoiceCatalog {
    static let edgeRecommended: [VoiceOption] = [
        VoiceOption(
            voiceID: "es-ES-AlvaroNeural",
            name: "Álvaro · España",
            locale: "es-ES",
            gender: "Male",
            engine: .edge,
            hint: "Narrador cálido, ideal para ensayos y no ficción"
        ),
        VoiceOption(
            voiceID: "es-ES-ElviraNeural",
            name: "Elvira · España",
            locale: "es-ES",
            gender: "Female",
            engine: .edge,
            hint: "Clara y expresiva, muy natural en castellano"
        ),
        VoiceOption(
            voiceID: "es-ES-XimenaNeural",
            name: "Ximena · España",
            locale: "es-ES",
            gender: "Female",
            engine: .edge,
            hint: "Tono contemporáneo, buena para narrativa"
        ),
        VoiceOption(
            voiceID: "es-MX-JorgeNeural",
            name: "Jorge · México",
            locale: "es-MX",
            gender: "Male",
            engine: .edge,
            hint: "Narración latinoamericana masculina"
        ),
        VoiceOption(
            voiceID: "es-MX-DaliaNeural",
            name: "Dalia · México",
            locale: "es-MX",
            gender: "Female",
            engine: .edge,
            hint: "Cálida y conversacional"
        ),
        VoiceOption(
            voiceID: "es-AR-TomasNeural",
            name: "Tomás · Argentina",
            locale: "es-AR",
            gender: "Male",
            engine: .edge,
            hint: "Acento rioplatense"
        ),
        VoiceOption(
            voiceID: "es-AR-ElenaNeural",
            name: "Elena · Argentina",
            locale: "es-AR",
            gender: "Female",
            engine: .edge,
            hint: "Acento rioplatense. Pronuncia símbolos: deja «Omitir símbolos» activado."
        ),
        VoiceOption(
            voiceID: "es-CO-GonzaloNeural",
            name: "Gonzalo · Colombia",
            locale: "es-CO",
            gender: "Male",
            engine: .edge,
            hint: "Neutro latino, muy inteligible"
        ),
        VoiceOption(
            voiceID: "es-CO-SalomeNeural",
            name: "Salomé · Colombia",
            locale: "es-CO",
            gender: "Female",
            engine: .edge,
            hint: "Suave y clara"
        ),
        VoiceOption(
            voiceID: "es-US-AlonsoNeural",
            name: "Alonso · US Spanish",
            locale: "es-US",
            gender: "Male",
            engine: .edge,
            hint: "Español de Estados Unidos"
        ),
        VoiceOption(
            voiceID: "es-US-PalomaNeural",
            name: "Paloma · US Spanish",
            locale: "es-US",
            gender: "Female",
            engine: .edge,
            hint: "Español de Estados Unidos"
        ),
        VoiceOption(
            voiceID: "en-US-AndrewMultilingualNeural",
            name: "Andrew · Multilingüe",
            locale: "en-US",
            gender: "Male",
            engine: .edge,
            hint: "Una de las más naturales. Habla español e inglés"
        ),
        VoiceOption(
            voiceID: "en-US-AvaMultilingualNeural",
            name: "Ava · Multilingüe",
            locale: "en-US",
            gender: "Female",
            engine: .edge,
            hint: "Muy expresiva. Habla español e inglés"
        ),
        VoiceOption(
            voiceID: "en-US-EmmaMultilingualNeural",
            name: "Emma · Multilingüe",
            locale: "en-US",
            gender: "Female",
            engine: .edge,
            hint: "Narradora premium, prosodia rica"
        ),
        VoiceOption(
            voiceID: "en-US-BrianMultilingualNeural",
            name: "Brian · Multilingüe",
            locale: "en-US",
            gender: "Male",
            engine: .edge,
            hint: "Voz grave, estilo documental"
        ),
        VoiceOption(
            voiceID: "en-US-AriaNeural",
            name: "Aria · USA",
            locale: "en-US",
            gender: "Female",
            engine: .edge,
            hint: "Clásica neural en inglés"
        ),
        VoiceOption(
            voiceID: "en-US-GuyNeural",
            name: "Guy · USA",
            locale: "en-US",
            gender: "Male",
            engine: .edge,
            hint: "Narrador estadounidense"
        ),
        VoiceOption(
            voiceID: "en-GB-SoniaNeural",
            name: "Sonia · UK",
            locale: "en-GB",
            gender: "Female",
            engine: .edge,
            hint: "Inglés británico"
        ),
        VoiceOption(
            voiceID: "en-GB-RyanNeural",
            name: "Ryan · UK",
            locale: "en-GB",
            gender: "Male",
            engine: .edge,
            hint: "Inglés británico"
        ),
        VoiceOption(
            voiceID: "fr-FR-VivienneMultilingualNeural",
            name: "Vivienne · Francés multilingüe",
            locale: "fr-FR",
            gender: "Female",
            engine: .edge,
            hint: "Francés natural"
        ),
        VoiceOption(
            voiceID: "pt-BR-ThalitaMultilingualNeural",
            name: "Thalita · Portugués BR",
            locale: "pt-BR",
            gender: "Female",
            engine: .edge,
            hint: "Portugués brasileño"
        )
    ]

    static let openaiVoices: [VoiceOption] = [
        VoiceOption(voiceID: "coral", name: "Coral", locale: "multi", gender: "Female", engine: .openai, hint: "Cálida, narrativa, excelente para audiolibros"),
        VoiceOption(voiceID: "verse", name: "Verse", locale: "multi", gender: "Male", engine: .openai, hint: "Literaria, gran rango emocional"),
        VoiceOption(voiceID: "ballad", name: "Ballad", locale: "multi", gender: "Male", engine: .openai, hint: "Suave y expresiva, tono de cuento"),
        VoiceOption(voiceID: "sage", name: "Sage", locale: "multi", gender: "Female", engine: .openai, hint: "Serena, ideal para no ficción"),
        VoiceOption(voiceID: "ash", name: "Ash", locale: "multi", gender: "Male", engine: .openai, hint: "Cercana y conversacional"),
        VoiceOption(voiceID: "alloy", name: "Alloy", locale: "multi", gender: "Neutral", engine: .openai, hint: "Neutra y clara"),
        VoiceOption(voiceID: "echo", name: "Echo", locale: "multi", gender: "Male", engine: .openai, hint: "Firme, documental"),
        VoiceOption(voiceID: "fable", name: "Fable", locale: "multi", gender: "Male", engine: .openai, hint: "Británica, narrativa"),
        VoiceOption(voiceID: "onyx", name: "Onyx", locale: "multi", gender: "Male", engine: .openai, hint: "Grave y autoritaria"),
        VoiceOption(voiceID: "nova", name: "Nova", locale: "multi", gender: "Female", engine: .openai, hint: "Energética y nítida"),
        VoiceOption(voiceID: "shimmer", name: "Shimmer", locale: "multi", gender: "Female", engine: .openai, hint: "Suave y luminosa")
    ]

    static let grokVoices: [VoiceOption] = [
        VoiceOption(voiceID: "ara", name: "Ara", locale: "multi", gender: "Female", engine: .grok, hint: "Cálida y conversacional. Muy buena para audiolibros en español"),
        VoiceOption(voiceID: "eve", name: "Eve", locale: "multi", gender: "Female", engine: .grok, hint: "Enérgica y nítida. Voz por defecto de Grok"),
        VoiceOption(voiceID: "rex", name: "Rex", locale: "multi", gender: "Male", engine: .grok, hint: "Segura y clara. Estilo documental / guía"),
        VoiceOption(voiceID: "sal", name: "Sal", locale: "multi", gender: "Male", engine: .grok, hint: "Suave y versátil, buen narrador neutro"),
        VoiceOption(voiceID: "leo", name: "Leo", locale: "multi", gender: "Male", engine: .grok, hint: "Cercana y expresiva"),
        VoiceOption(voiceID: "luna", name: "Luna", locale: "multi", gender: "Female", engine: .grok, hint: "Serena, tono de cuento"),
        VoiceOption(voiceID: "celeste", name: "Celeste", locale: "multi", gender: "Female", engine: .grok, hint: "Luminosa, buena para narrativa"),
        VoiceOption(voiceID: "iris", name: "Iris", locale: "multi", gender: "Female", engine: .grok, hint: "Clara y contemporánea"),
        VoiceOption(voiceID: "carina", name: "Carina", locale: "multi", gender: "Female", engine: .grok, hint: "Cálida, registro de narradora"),
        VoiceOption(voiceID: "ursa", name: "Ursa", locale: "multi", gender: "Female", engine: .grok, hint: "Grave y pausada"),
        VoiceOption(voiceID: "lux", name: "Lux", locale: "multi", gender: "Female", engine: .grok, hint: "Brillante y directa"),
        VoiceOption(voiceID: "atlas", name: "Atlas", locale: "multi", gender: "Male", engine: .grok, hint: "Grave, estilo guía / no ficción"),
        VoiceOption(voiceID: "orion", name: "Orion", locale: "multi", gender: "Male", engine: .grok, hint: "Firme y articulado"),
        VoiceOption(voiceID: "helios", name: "Helios", locale: "multi", gender: "Male", engine: .grok, hint: "Enérgico, buen ritmo"),
        VoiceOption(voiceID: "perseus", name: "Perseus", locale: "multi", gender: "Male", engine: .grok, hint: "Épico, adecuado para aventura"),
        VoiceOption(voiceID: "zenith", name: "Zenith", locale: "multi", gender: "Male", engine: .grok, hint: "Limpio y profesional"),
        VoiceOption(voiceID: "altair", name: "Altair", locale: "multi", gender: "Male", engine: .grok, hint: "Neutro y preciso"),
        VoiceOption(voiceID: "helix", name: "Helix", locale: "multi", gender: "Male", engine: .grok, hint: "Técnico, claro en listas"),
        VoiceOption(voiceID: "kepler", name: "Kepler", locale: "multi", gender: "Male", engine: .grok, hint: "Calmado, buen para explicaciones"),
        VoiceOption(voiceID: "rigel", name: "Rigel", locale: "multi", gender: "Male", engine: .grok, hint: "Nítido y directo"),
        VoiceOption(voiceID: "cosmo", name: "Cosmo", locale: "multi", gender: "Male", engine: .grok, hint: "Ligero, conversacional"),
        VoiceOption(voiceID: "sirius", name: "Sirius", locale: "multi", gender: "Male", engine: .grok, hint: "Presentador, muy inteligible"),
        VoiceOption(voiceID: "lumen", name: "Lumen", locale: "multi", gender: "Male", engine: .grok, hint: "Suave, tono de ensayo"),
        VoiceOption(voiceID: "castor", name: "Castor", locale: "multi", gender: "Male", engine: .grok, hint: "Robusto, narración de acción"),
        VoiceOption(voiceID: "zagan", name: "Zagan", locale: "multi", gender: "Male", engine: .grok, hint: "Oscuro, buen para thriller"),
        VoiceOption(voiceID: "naksh", name: "Naksh", locale: "multi", gender: "Male", engine: .grok, hint: "Cálido, cadencia marcada")
    ]

    static let googleVoices: [VoiceOption] = [
        VoiceOption(voiceID: "es-ES-Journey-F", name: "Journey · Princesa de Cuento 👑 (España)", locale: "es-ES", gender: "Female", engine: .google, hint: "Voz femenina hiperrealista, dulce, mágica y cautivadora"),
        VoiceOption(voiceID: "es-ES-Journey-D", name: "Journey · Narrador Legendario (España)", locale: "es-ES", gender: "Male", engine: .google, hint: "Voz masculina profunda, ideal para fantasía y literatura épica"),
        VoiceOption(voiceID: "es-ES-Studio-C", name: "Studio · Dama Distinguida ✨ (España)", locale: "es-ES", gender: "Female", engine: .google, hint: "Grabada en estudio acústico, timbre fino y elegante"),
        VoiceOption(voiceID: "es-ES-Studio-F", name: "Studio · Narradora Cálida (España)", locale: "es-ES", gender: "Female", engine: .google, hint: "Voz de estudio profesional, articulación impecable"),
        VoiceOption(voiceID: "es-ES-Neural2-A", name: "Neural2 · Clara y Juvenil (España)", locale: "es-ES", gender: "Female", engine: .google, hint: "Voz femenina moderna y cristalina de Google DeepMind"),
        VoiceOption(voiceID: "es-ES-Neural2-C", name: "Neural2 · Dulce y Melódica 🌸 (España)", locale: "es-ES", gender: "Female", engine: .google, hint: "Cadencia musical suave, entonación placentera"),
        VoiceOption(voiceID: "es-ES-Neural2-E", name: "Neural2 · Princesa Serena (España)", locale: "es-ES", gender: "Female", engine: .google, hint: "Tono delicado, relajante y acogedor"),
        VoiceOption(voiceID: "es-ES-Neural2-B", name: "Neural2 · Narrador Clásico (España)", locale: "es-ES", gender: "Male", engine: .google, hint: "Voz masculina sobria y equilibrada"),
        VoiceOption(voiceID: "es-US-Journey-F", name: "Journey · Princesa Latina 👑 (Latinoamérica)", locale: "es-US", gender: "Female", engine: .google, hint: "Español neutro / US, encantadora, fluida y luminosa"),
        VoiceOption(voiceID: "es-US-Journey-D", name: "Journey · Narrador Latino (Latinoamérica)", locale: "es-US", gender: "Male", engine: .google, hint: "Voz masculina envolvente con acento neutro"),
        VoiceOption(voiceID: "es-US-Neural2-A", name: "Neural2 · Sofía (Latinoamérica)", locale: "es-US", gender: "Female", engine: .google, hint: "Voz femenina cálida y vivaz"),
        VoiceOption(voiceID: "es-US-Neural2-C", name: "Neural2 · Camila (Latinoamérica)", locale: "es-US", gender: "Female", engine: .google, hint: "Voz femenina expresiva, estilo audiolibro moderno"),
        VoiceOption(voiceID: "gemini-kore", name: "Gemini · Kore (Princesa Dulce) 🌸", locale: "multi", gender: "Female", engine: .google, hint: "Voz de Google Gemini AI, dulce, juvenil y radiante"),
        VoiceOption(voiceID: "gemini-aoede", name: "Gemini · Aoede (Musa Artística) 🎶", locale: "multi", gender: "Female", engine: .google, hint: "Voz poética y artística de Google Gemini"),
        VoiceOption(voiceID: "gemini-leda", name: "Gemini · Leda (Regia y Elegante) 👑", locale: "multi", gender: "Female", engine: .google, hint: "Voz distinguida, majestuosa y refinada"),
        VoiceOption(voiceID: "gemini-callirrhoe", name: "Gemini · Callirrhoe (Cristalina) 💧", locale: "multi", gender: "Female", engine: .google, hint: "Voz etérea, poética y serena"),
        VoiceOption(voiceID: "gemini-puck", name: "Gemini · Puck (Ágil y Alegre)", locale: "multi", gender: "Male", engine: .google, hint: "Voz vivaz y animada, perfecta para cuentos"),
        VoiceOption(voiceID: "gemini-charon", name: "Gemini · Charon (Filosófica y Solemne)", locale: "multi", gender: "Male", engine: .google, hint: "Voz masculina grave y pausada"),
        VoiceOption(voiceID: "gemini-fenrir", name: "Gemini · Fenrir (Potente y Narrativa)", locale: "multi", gender: "Male", engine: .google, hint: "Voz masculina firme, estilo novela de misterio"),
        VoiceOption(voiceID: "gemini-zephyr", name: "Gemini · Zephyr (Cálida y Suave)", locale: "multi", gender: "Male", engine: .google, hint: "Voz cálida y conversacional"),
        VoiceOption(voiceID: "en-US-Journey-F", name: "Journey · English Princess 👑", locale: "en-US", gender: "Female", engine: .google, hint: "Hiperrealista en inglés, dulce y expresiva"),
        VoiceOption(voiceID: "en-US-Journey-O", name: "Journey · English Conversational", locale: "en-US", gender: "Female", engine: .google, hint: "Voz femenina luminosa y fluida"),
        VoiceOption(voiceID: "en-US-Studio-O", name: "Studio · English Professional", locale: "en-US", gender: "Female", engine: .google, hint: "Voz de estudio de élite para audiolibros")
    ]

    static func voices(for engine: TTSEngineKind) -> [VoiceOption] {
        switch engine {
        case .edge: return edgeRecommended
        case .google: return googleVoices
        case .grok: return grokVoices
        case .openai: return openaiVoices
        }
    }

    static func sampleText(for voice: VoiceOption) -> String {
        if voice.locale.hasPrefix("es") || voice.engine == .openai || voice.engine == .grok || voice.engine == .google {
            return "Hola. Esta es una demostración de voz narrativa. La entonación se adapta al carácter de cada frase: las preguntas suben, las afirmaciones se asientan, y el relato respira. ¿Se nota la diferencia frente a una voz robótica?"
        }
        if voice.locale.hasPrefix("fr") {
            return "Bonjour. Voici une démonstration de narration. L'intonation s'adapte au caractère de chaque phrase."
        }
        if voice.locale.hasPrefix("pt") {
            return "Olá. Esta é uma demonstração de narração. A entonação se adapta ao caráter de cada frase."
        }
        return "Hello. This is a narrative voice demonstration. Intonation adapts to each sentence — questions rise, statements settle, and the story breathes. Hear how different that is from a robotic Mac voice?"
    }

    static let openaiAudiobookInstructions = """
    Narrate this as a professional audiobook reader. Adapt intonation, rhythm and emotion to the meaning of each sentence. Sound warm, human and expressive — never robotic, flat or singsong. Pause naturally at punctuation and paragraph breaks. Questions should rise; exclamations should carry energy; dialogue should feel spoken; descriptive passages should stay calm and immersive. If the text is in Spanish, use natural Spanish prosody. If it is in English, use natural English prosody. Do not add extra words.
    """
}
