import Foundation
import AppKit
import Combine

/// Represents an individual recorded step in an AppleScript macro
public struct RecordedActionItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let appleScriptSnippet: String
    public let iconName: String
}

/// Popular automation templates available for instant 1-click recording
public enum MacroTemplate: String, CaseIterable, Identifiable {
    case deepWork = "Deep Work Mode"
    case meetingPrep = "Meeting Setup"
    case devStack = "Developer Workspace"
    case cleanDisplay = "Clean & Present"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .deepWork: return "Mutes notifications, launches code editor & plays focus music"
        case .meetingPrep: return "Opens meeting room, checks camera & sets audio levels"
        case .devStack: return "Launches Terminal & Browser split 50/50 on screen"
        case .cleanDisplay: return "Hides all background apps and prepares screen recording"
        }
    }
    
    public var iconName: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .meetingPrep: return "video.badge.waveform"
        case .devStack: return "chevron.left.forwardslash.chevron.right"
        case .cleanDisplay: return "sparkles.tv"
        }
    }
}

/// Manages recording and synthesis of AppleScript macros into launchable Shortcuts Engine items.
public class MacroRecorderManager: ObservableObject {
    public static let shared = MacroRecorderManager()
    
    @Published public var isRecording: Bool = false
    @Published public var recordedActions: [RecordedActionItem] = []
    @Published public var generatedScript: String = ""
    @Published public var macroName: String = "My Action Macro"
    @Published public var selectedIcon: String = "bolt.circle.fill"
    @Published public var selectedColorHex: String = "#FF9500"
    
    private var workspaceObserver: NSObjectProtocol?
    
    private init() {}
    
    public func startRecording() {
        recordedActions.removeAll()
        generatedScript = "-- NotchX Automated Macro\n"
        isRecording = true
        macroName = "Macro \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))"
        
        // Listen for user switching apps while recording
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self, self.isRecording else { return }
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let name = app.localizedName,
               name != "NotchX" {
                self.recordAppSwitch(appName: name)
            }
        }
    }
    
    public func stopRecording() {
        isRecording = false
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        recompileScript()
    }
    
    public func recordAppSwitch(appName: String) {
        let snippet = "tell application \"\(appName)\" to activate\ndelay 0.3"
        let action = RecordedActionItem(
            title: "Activate \(appName)",
            subtitle: "Brings \(appName) to foreground",
            appleScriptSnippet: snippet,
            iconName: "app.badge.checkmark"
        )
        recordedActions.append(action)
        recompileScript()
    }
    
    public func addKeystroke(key: String, modifiers: [String] = []) {
        var modString = ""
        if !modifiers.isEmpty {
            let quoted = modifiers.map { "\($0) down" }.joined(separator: ", ")
            modString = " using {\(quoted)}"
        }
        let snippet = "tell application \"System Events\" to keystroke \"\(key)\"\(modString)\ndelay 0.2"
        let action = RecordedActionItem(
            title: "Keystroke: \(modifiers.joined(separator: "+")) + \(key.uppercased())",
            subtitle: "Simulates keyboard shortcut",
            appleScriptSnippet: snippet,
            iconName: "keyboard"
        )
        recordedActions.append(action)
        recompileScript()
    }
    
    public func addDelay(seconds: Double) {
        let snippet = "delay \(seconds)"
        let action = RecordedActionItem(
            title: "Wait \(seconds)s",
            subtitle: "Pause before next action",
            appleScriptSnippet: snippet,
            iconName: "timer"
        )
        recordedActions.append(action)
        recompileScript()
    }
    
    public func loadTemplate(_ template: MacroTemplate) {
        recordedActions.removeAll()
        switch template {
        case .deepWork:
            macroName = "Deep Work Mode"
            selectedIcon = "brain.head.profile"
            selectedColorHex = "#AF52DE"
            
            recordedActions.append(RecordedActionItem(
                title: "Launch Code Workspace",
                subtitle: "Opens Terminal / Xcode",
                appleScriptSnippet: "tell application \"Terminal\" to activate\ndelay 0.4",
                iconName: "terminal"
            ))
            recordedActions.append(RecordedActionItem(
                title: "Play Focus Music",
                subtitle: "Starts Music / Spotify playback",
                appleScriptSnippet: "tell application \"Music\" to play\ndelay 0.2",
                iconName: "music.note"
            ))
            recordedActions.append(RecordedActionItem(
                title: "Set Volume to 40%",
                subtitle: "Optimizes listening volume",
                appleScriptSnippet: "set volume output volume 40",
                iconName: "speaker.wave.2"
            ))
            
        case .meetingPrep:
            macroName = "Meeting Setup"
            selectedIcon = "video.badge.waveform"
            selectedColorHex = "#34C759"
            
            recordedActions.append(RecordedActionItem(
                title: "Open Google Meet",
                subtitle: "Launches meeting in default browser",
                appleScriptSnippet: "open location \"https://meet.google.com/new\"\ndelay 0.8",
                iconName: "video"
            ))
            recordedActions.append(RecordedActionItem(
                title: "Calibrate Audio",
                subtitle: "Unmutes system audio & mic",
                appleScriptSnippet: "set volume input volume 100\nset volume output volume 75",
                iconName: "mic"
            ))
            
        case .devStack:
            macroName = "Dev Workspace"
            selectedIcon = "chevron.left.forwardslash.chevron.right"
            selectedColorHex = "#007AFF"
            
            recordedActions.append(RecordedActionItem(
                title: "Launch Terminal",
                subtitle: "Opens development console",
                appleScriptSnippet: "tell application \"Terminal\" to activate\ndelay 0.5",
                iconName: "terminal"
            ))
            recordedActions.append(RecordedActionItem(
                title: "Launch Browser",
                subtitle: "Opens localhost in Safari",
                appleScriptSnippet: "tell application \"Safari\" to open location \"http://localhost:3000\"\ndelay 0.5",
                iconName: "safari"
            ))
            
        case .cleanDisplay:
            macroName = "Clean Screen"
            selectedIcon = "sparkles.tv"
            selectedColorHex = "#FF9500"
            
            recordedActions.append(RecordedActionItem(
                title: "Hide Inactive Apps",
                subtitle: "Focus on frontmost task",
                appleScriptSnippet: "tell application \"System Events\" to set visible of every process whose visible is true and frontmost is false to false",
                iconName: "eye.slash"
            ))
        }
        
        recompileScript()
    }
    
    private func recompileScript() {
        var script = "-- NotchX Macro: \(macroName)\n"
        for action in recordedActions {
            script += "\n-- \(action.title)\n"
            script += "\(action.appleScriptSnippet)\n"
        }
        generatedScript = script
    }
    
    /// Compiles and saves the macro as a persistent, clickable icon inside SettingsManager.shortcuts
    public func saveMacroToShortcuts() {
        recompileScript()
        
        let item = ShortcutItem(
            name: macroName.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: selectedIcon,
            actionType: .appleScript,
            actionData: generatedScript,
            colorHex: selectedColorHex
        )
        
        DispatchQueue.main.async {
            SettingsManager.shared.shortcuts.append(item)
            SettingsManager.shared.save()
            AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
            self.stopRecording()
        }
    }
}
