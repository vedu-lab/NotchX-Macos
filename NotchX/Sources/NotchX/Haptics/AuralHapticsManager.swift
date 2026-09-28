import Foundation
import AppKit
import AVFoundation

/// High-end bespoke UI sound cues partner with trackpad haptics
public enum AuralSound: String, CaseIterable, Identifiable {
    case tock = "Organic Tock"
    case whoosh = "Tactile Whoosh"
    case mechanicalClick = "Mechanical Click"
    case sparkleTick = "Sparkle Tick"
    case completionChime = "Completion Chime"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .tock: return "Subtle organic wood/slate tock when opening/closing or switching tabs"
        case .whoosh: return "Soft velvety fluid whoosh when dropping items into the vault"
        case .mechanicalClick: return "Precision mechanical latch click for kill switch & buttons"
        case .sparkleTick: return "Delicate crystalline micro-tick for HUD sliders & volume keys"
        case .completionChime: return "Warm spatial harmonic chord when saving actions or tasks"
        }
    }
}

/// Trackpad haptic feedback strength
public enum HapticFeedbackPattern {
    case alignment
    case levelChange
    case generic
    case none
}

/// Manages bespoke sound synthesis and synchronized sub-millisecond trackpad aural haptics.
/// Operates with 100% in-memory PCM synthesis for 0ms latency with zero disk dependencies.
public class AuralHapticsManager: ObservableObject {
    public static let shared = AuralHapticsManager()
    
    private var playerPools: [AuralSound: [AVAudioPlayer]] = [:]
    private var poolIndices: [AuralSound: Int] = [:]
    private let queue = DispatchQueue(label: "com.notchx.auralhaptics", qos: .userInteractive)
    
    private init() {
        prepareAudioEngines()
    }
    
    /// Pre-synthesize all luxury UI acoustic waveforms into memory at startup
    private func prepareAudioEngines() {
        for sound in AuralSound.allCases {
            let data = synthesizeWAV(for: sound)
            var pool: [AVAudioPlayer] = []
            
            // Pool of 3 players per sound for seamless polyphonic overlap
            for _ in 0..<3 {
                if let player = try? AVAudioPlayer(data: data) {
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            playerPools[sound] = pool
            poolIndices[sound] = 0
        }
    }
    
    /// Play a bespoke UI acoustic sound with synchronized trackpad haptics
    public func play(_ sound: AuralSound, haptic: HapticFeedbackPattern = .generic) {
        let settings = SettingsManager.shared
        guard settings.auralHapticsEnabled else { return }
        
        let volume = Float(settings.auralHapticsVolume)
        
        // 1. Synchronized Trackpad Haptic Pulse
        triggerHaptic(haptic)
        
        // 2. Play Sub-millisecond Audio Cue
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let pool = self.playerPools[sound], !pool.isEmpty else { return }
            
            let idx = (self.poolIndices[sound] ?? 0) % pool.count
            self.poolIndices[sound] = (idx + 1) % pool.count
            
            let player = pool[idx]
            player.volume = volume
            player.currentTime = 0
            player.play()
        }
    }
    
    /// Execute native macOS trackpad physical haptic vibration
    public func triggerHaptic(_ pattern: HapticFeedbackPattern) {
        DispatchQueue.main.async {
            switch pattern {
            case .alignment:
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            case .levelChange:
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            case .generic:
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            case .none:
                break
            }
        }
    }
    
    // MARK: - In-Memory Acoustic Synthesis Engine
    
    private func synthesizeWAV(for sound: AuralSound) -> Data {
        let sampleRate = 44100
        var samples: [Int16] = []
        
        switch sound {
        case .tock:
            // Subtle, organic wood/slate tock (45ms)
            // Frequency rapidly sweeps from 480Hz down to 140Hz with high-order damping
            let duration = 0.045
            let totalSamples = Int(Double(sampleRate) * duration)
            var phase: Double = 0.0
            
            for i in 0..<totalSamples {
                let t = Double(i) / Double(sampleRate)
                let freq = 140.0 + (340.0 * exp(-70.0 * t))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                
                // Exponential decay envelope with 1ms attack ramp
                let attack = min(1.0, t / 0.0015)
                let decay = exp(-52.0 * t)
                let env = attack * decay
                
                // Fundamental + organic 2nd harmonic
                let val = (sin(phase) * 0.85) + (sin(phase * 2.0) * 0.15)
                let sampleVal = Int16(max(-32767.0, min(32767.0, val * env * 24000.0)))
                samples.append(sampleVal)
            }
            
        case .whoosh:
            // Soft tactile fluid dynamic whoosh (130ms)
            // Multi-frequency FM sweep with soft attack and velvet decay
            let duration = 0.130
            let totalSamples = Int(Double(sampleRate) * duration)
            var phase1: Double = 0.0
            var phase2: Double = 0.0
            
            for i in 0..<totalSamples {
                let t = Double(i) / Double(sampleRate)
                
                // Sweep up from 220Hz to 580Hz then fall to 260Hz
                let freq1 = 220.0 + (360.0 * sin((t / duration) * .pi))
                let freq2 = freq1 * 1.52
                
                phase1 += 2.0 * .pi * freq1 / Double(sampleRate)
                phase2 += 2.0 * .pi * freq2 / Double(sampleRate)
                
                // Smooth bell-shaped envelope
                let attack = min(1.0, t / 0.025)
                let decay = exp(-18.0 * max(0.0, t - 0.025))
                let env = attack * decay
                
                // Pseudo-noise / air turbulence modulation
                let noise = sin(t * 3141.5) * 0.25
                let val = (sin(phase1) * 0.6) + (sin(phase2) * 0.3) + noise
                let sampleVal = Int16(max(-32767.0, min(32767.0, val * env * 20000.0)))
                samples.append(sampleVal)
            }
            
        case .mechanicalClick:
            // Precision luxury watch/switch mechanical click (32ms)
            // Dual micro-transients: initial 3.5kHz snap + 1.4kHz body latch
            let duration = 0.032
            let totalSamples = Int(Double(sampleRate) * duration)
            
            for i in 0..<totalSamples {
                let t = Double(i) / Double(sampleRate)
                var val: Double = 0.0
                
                if t < 0.006 {
                    // Transient 1: Sharp click at 3500Hz
                    let env = exp(-450.0 * t)
                    val = sin(2.0 * .pi * 3500.0 * t) * env * 0.9
                } else if t < 0.010 {
                    // Micro-pause
                    val = sin(2.0 * .pi * 850.0 * t) * 0.05
                } else {
                    // Transient 2: Mechanical latch closure at 1450Hz
                    let t2 = t - 0.010
                    let env = exp(-130.0 * t2)
                    val = (sin(2.0 * .pi * 1450.0 * t2) * 0.75 + sin(2.0 * .pi * 2100.0 * t2) * 0.25) * env
                }
                
                let sampleVal = Int16(max(-32767.0, min(32767.0, val * 26000.0)))
                samples.append(sampleVal)
            }
            
        case .sparkleTick:
            // Subtle, delicate crystalline micro-tick for HUD adjustments (20ms)
            let duration = 0.020
            let totalSamples = Int(Double(sampleRate) * duration)
            
            for i in 0..<totalSamples {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-140.0 * t)
                let val = (sin(2.0 * .pi * 2400.0 * t) * 0.8) + (sin(2.0 * .pi * 4800.0 * t) * 0.2)
                let sampleVal = Int16(max(-32767.0, min(32767.0, val * env * 18000.0)))
                samples.append(sampleVal)
            }
            
        case .completionChime:
            // Warm spatial harmonic completion chord (240ms)
            // C6 (1046.5Hz) + E6 (1318.5Hz) + G6 (1567.98Hz) + C7 (2093Hz)
            let duration = 0.240
            let totalSamples = Int(Double(sampleRate) * duration)
            let freqs = [1046.50, 1318.51, 1567.98, 2093.00]
            let weights = [0.40, 0.28, 0.22, 0.10]
            
            for i in 0..<totalSamples {
                let t = Double(i) / Double(sampleRate)
                let attack = min(1.0, t / 0.004)
                let decay = exp(-13.5 * t)
                let env = attack * decay
                
                var val: Double = 0.0
                for (idx, f) in freqs.enumerated() {
                    val += sin(2.0 * .pi * f * t) * weights[idx]
                }
                
                let sampleVal = Int16(max(-32767.0, min(32767.0, val * env * 25000.0)))
                samples.append(sampleVal)
            }
        }
        
        return buildRIFFWAV(samples: samples, sampleRate: sampleRate)
    }
    
    /// Construct standard 16-bit Mono PCM WAV RIFF container
    private func buildRIFFWAV(samples: [Int16], sampleRate: Int) -> Data {
        var data = Data()
        let numSamples = samples.count
        let subChunk2Size = numSamples * 2
        let chunkSize = 36 + subChunk2Size
        
        // "RIFF"
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        var cs = UInt32(chunkSize).littleEndian
        data.append(Data(bytes: &cs, count: 4))
        // "WAVE"
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        // "fmt "
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        var sc1 = UInt32(16).littleEndian
        data.append(Data(bytes: &sc1, count: 4))
        var af = UInt16(1).littleEndian // PCM
        data.append(Data(bytes: &af, count: 2))
        var nc = UInt16(1).littleEndian // Mono
        data.append(Data(bytes: &nc, count: 2))
        var sr = UInt32(sampleRate).littleEndian
        data.append(Data(bytes: &sr, count: 4))
        var br = UInt32(sampleRate * 2).littleEndian
        data.append(Data(bytes: &br, count: 4))
        var ba = UInt16(2).littleEndian
        data.append(Data(bytes: &ba, count: 2))
        var bps = UInt16(16).littleEndian // 16-bit
        data.append(Data(bytes: &bps, count: 2))
        // "data"
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        var sc2 = UInt32(subChunk2Size).littleEndian
        data.append(Data(bytes: &sc2, count: 4))
        
        // Samples
        samples.withUnsafeBufferPointer { buffer in
            data.append(buffer)
        }
        
        return data
    }
}
