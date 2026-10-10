import Darwin
import Foundation

enum SystemBootTimeReader {
    static func bootTime() -> TimeInterval? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0,
              bootTime.tv_sec > 0 else {
            return nil
        }
        return TimeInterval(bootTime.tv_sec)
    }
}
