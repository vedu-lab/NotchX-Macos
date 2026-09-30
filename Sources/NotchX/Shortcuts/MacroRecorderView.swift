import SwiftUI
import AppKit

/// Observable state for macro builder UI without @State macro
public class MacroBuilderState: ObservableObject {
    public static let shared = MacroBuilderState()
    @Published public var customKey: String = "C"
    @Published public var useCmd: Bool = true
    @Published public var useShift: Bool = false
    @Published public var useOpt: Bool = false
    @Published public var testOutput: String = ""
    @Published public var isTesting: Bool = false
}

/// Power-User AppleScript Macro Recorder View
/// Records frontmost app switches, keystroke sequences, and multi-step workflows,
/// compiling them into persistent, launchable icons inside the user's Shortcuts Engine.
public struct MacroRecorderView: View {
    @ObservedObject private var recorder = MacroRecorderManager.shared
    @ObservedObject private var state = MacroBuilderState.shared
    public let onDone: () -> Void
    
    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Title & Action Controls
            HStack(spacing: 8) {
                // Recording Status Pulse
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .shadow(color: recorder.isRecording ? .red : .clear, radius: 4)
                
                Text(recorder.isRecording ? "RECORDING ACTIONS..." : "MACRO RECORDER")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(recorder.isRecording ? .red : .white.opacity(0.85))
                    .tracking(0.8)
                
                Spacer()
                
                // Record / Stop Toggle Button
                Button(action: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(recorder.isRecording ? .white : .red)
                        Text(recorder.isRecording ? "Stop" : "Record")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(recorder.isRecording ? Color.red : Color.red.opacity(0.25))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                
                // Save Macro Button
                Button(action: {
                    recorder.saveMacroToShortcuts()
                    onDone()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Save Macro")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(recorder.recordedActions.isEmpty && recorder.generatedScript.isEmpty)
                
                // Cancel / Done Button
                Button(action: {
                    recorder.stopRecording()
                    onDone()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Macro Name & Icon Selector
            HStack(spacing: 10) {
                // Icon Preview
                Image(systemName: recorder.selectedIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: recorder.selectedColorHex) ?? Color.blue)
                    .clipShape(Circle())
                
                TextField("Macro Name", text: $recorder.macroName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            }
            .padding(.horizontal, 4)
            
            // Row of Preset 1-Click Templates
            VStack(alignment: .leading, spacing: 4) {
                Text("QUICK TEMPLATES")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MacroTemplate.allCases) { template in
                            Button(action: {
                                recorder.loadTemplate(template)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: template.iconName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(template.rawValue)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Recorded Action Steps List & Script Preview
            HStack(spacing: 12) {
                // Left: Recorded Steps
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECORDED ACTIONS (\(recorder.recordedActions.count))")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    ScrollView {
                        VStack(spacing: 5) {
                            if recorder.recordedActions.isEmpty {
                                Text("Click Record or select a template to build actions")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(recorder.recordedActions) { item in
                                    HStack(spacing: 6) {
                                        Image(systemName: item.iconName)
                                            .font(.system(size: 9))
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title)
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text(item.subtitle)
                                                .font(.system(size: 8))
                                                .foregroundColor(.white.opacity(0.45))
                                        }
                                        Spacer()
                                    }
                                    .padding(6)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .frame(height: 75)
                }
                .frame(maxWidth: .infinity)
                
                // Right: Live AppleScript Code Preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("APPLESCRIPT SOURCE")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    ScrollView {
                        Text(recorder.generatedScript.isEmpty ? "-- Script will appear here" : recorder.generatedScript)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundColor(Color.green.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    }
                    .frame(height: 75)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
