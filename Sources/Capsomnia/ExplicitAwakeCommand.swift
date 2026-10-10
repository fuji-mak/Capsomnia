import Foundation

/// Runs the explicit CLI operation through the app's existing hardware and
/// helper paths. The injectable boundaries let tests verify sleep ordering
/// without changing the test machine's power state.
enum ExplicitAwakeCommand {
    static func run(
        target: Bool,
        setCapsLock: (Bool, @escaping (CapsLockToggleResult) -> Void) -> Void,
        synchronize: @escaping (Bool) -> Bool,
        readCapsLock: @escaping () -> Bool?,
        sleep: @escaping () -> CommandResult,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        setCapsLock(target) { result in
            guard result == .changed(to: target) else {
                completion(.failure(Failure("Could not set Caps Lock: \(result)")))
                return
            }
            guard synchronize(target), readCapsLock() == target else {
                completion(.failure(Failure("Sleep prevention could not be confirmed. Run cpsm doctor.")))
                return
            }
            guard !target else {
                completion(.success(false))
                return
            }
            let result = sleep()
            guard result.status == 0 else {
                completion(.failure(Failure("Sleep request failed: \(result.stderr)")))
                return
            }
            completion(.success(true))
        }
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
