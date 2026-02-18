import Foundation

/// Async semaphore to limit concurrent execution.
actor AsyncSemaphore {
    private let limit: Int
    private var currentCount: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(limit: Int) {
        self.limit = limit
    }
    
    func wait() async {
        if currentCount < limit {
            currentCount += 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            currentCount = max(0, currentCount - 1)
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}
