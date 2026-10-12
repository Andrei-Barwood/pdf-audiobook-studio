import SwiftUI

@main
struct PDFAudiobookStudioApp: App {
    @StateObject private var model = StudioViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 800, minHeight: 550)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Abrir PDF…") { model.openPDF() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Probar voz") { model.previewVoice() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Ajustes…") { model.showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
