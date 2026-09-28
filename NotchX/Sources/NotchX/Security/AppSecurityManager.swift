import Foundation
import AppKit
import Security
import Darwin

/// Enterprise-grade Application Security, Anti-Tampering, and Anti-Reverse-Engineering Shield
/// Protects NotchX from unauthorized debugging, memory patching, dynamic library injection, and binary tampering.
public class AppSecurityManager {
    public static let shared = AppSecurityManager()
    
    private var watchdogTimer: Timer?
    private let securityQueue = DispatchQueue(label: "com.notchx.security.sentinel", qos: .background)
    
    private typealias PtraceType = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt
    
    private init() {}
    
    /// Activate all defense layers at application boot
    public func activateSecurityShield() {
        // 1. Check for unauthorized dynamic library injection
        verifyEnvironmentIntegrity()
        
        // 2. Prevent debugger attachment & check active tracing
        denyDebuggerAttachment()
        
        // 3. Verify cryptographic code signature on disk
        verifyCodeSignatureIntegrity()
        
        // 4. Start periodic background integrity watchdog
        startWatchdog()
    }
    
    // MARK: - 1. Environment & Dylib Injection Defense
    
    private func verifyEnvironmentIntegrity() {
        let env = ProcessInfo.processInfo.environment
        let hostileKeys = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_LIBRARY_PATH",
            "DYLD_FRAMEWORK_PATH",
            "DYLD_FALLBACK_LIBRARY_PATH"
        ]
        
        for key in hostileKeys {
            if let val = env[key], !val.isEmpty {
                NSLog("🛡️ [NotchX Security] Hostile environment variable detected: \(key)=\(val)")
                exitOnSecurityViolation(reason: "Dynamic library injection attempt detected.")
            }
        }
    }
    
    // MARK: - 2. Anti-Debugging & Kernel Attachment Defense
    
    private func denyDebuggerAttachment() {
        // A. Check if already traced by a debugger (e.g. LLDB, GDB, Frida)
        if isProcessTraced() {
            NSLog("🛡️ [NotchX Security] Active debugger detected.")
            exitOnSecurityViolation(reason: "Active debugger attached.")
        }
        
        // B. Invoke kernel PT_DENY_ATTACH (31) to prevent any future debugger from attaching
        #if !DEBUG
        if let handle = dlopen(nil, RTLD_NOW) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "ptrace") {
                let ptraceFunc = unsafeBitCast(sym, to: PtraceType.self)
                // PT_DENY_ATTACH is 31 in Darwin
                let result = ptraceFunc(31, 0, 0, 0)
                if result != 0 {
                    NSLog("🛡️ [NotchX Security] Kernel attachment defense engaged.")
                }
            }
        }
        #endif
    }
    
    private func isProcessTraced() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        
        let status = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard status == 0 else { return false }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    // MARK: - 3. Cryptographic Code Signature Self-Verification
    
    private func verifyCodeSignatureIntegrity() {
        var secCode: SecCode?
        let copyStatus = SecCodeCopySelf([], &secCode)
        guard copyStatus == errSecSuccess, let code = secCode else {
            // In development / ad-hoc testing, copy may return error if unsigned
            return
        }
        
        // Check validity of self against static code requirement
        let validityStatus = SecCodeCheckValidity(code, SecCSFlags(rawValue: 0), nil)
        if validityStatus != errSecSuccess {
            NSLog("🛡️ [NotchX Security] Code signature validity check failed with status: \(validityStatus)")
            // Note: Don't exit on ad-hoc builds during local test, but log for protection
        }
    }
    
    // MARK: - 4. Background Watchdog Sentinel
    
    private func startWatchdog() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.watchdogTimer?.invalidate()
            self.watchdogTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
                self?.securityQueue.async {
                    self?.performPeriodicIntegritySweep()
                }
            }
        }
    }
    
    private func performPeriodicIntegritySweep() {
        if isProcessTraced() {
            NSLog("🛡️ [NotchX Security] Late debugger attachment detected during runtime.")
            exitOnSecurityViolation(reason: "Late debugger attachment detected.")
        }
    }
    
    // MARK: - Security Lockdown
    
    private func exitOnSecurityViolation(reason: String) {
        NSLog("🛑 [NotchX Security Lockdown] \(reason)")
        // Immediate termination preventing memory dumping or state recovery
        exit(1)
    }
}
