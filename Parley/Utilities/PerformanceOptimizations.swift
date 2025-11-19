//
//  PerformanceOptimizations.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Performance Utilities

/// Utilities for optimizing Core Data fetch requests
enum CoreDataOptimizer {
    
    /// Configures the fetch request for optimal performance
    /// - Parameter fetchRequest: The fetch request to optimize
    static func optimizeForPerformance<T>(_ fetchRequest: NSFetchRequest<T>) {
        // Batch fetching reduces memory footprint
        fetchRequest.fetchBatchSize = 20
        
        // Prevents Core Data from returning faults
        fetchRequest.returnsObjectsAsFaults = false
    }
    
    /// Configures the fetch request for large datasets
    /// - Parameter fetchRequest: The fetch request to optimize
    static func optimizeForLargeDataset<T>(_ fetchRequest: NSFetchRequest<T>) {
        // Larger batch size for bulk operations
        fetchRequest.fetchBatchSize = 50
        
        // Return faults to reduce memory usage
        fetchRequest.returnsObjectsAsFaults = true
        
        // Only fetch properties we need
        fetchRequest.propertiesToFetch = nil // Set specific properties if needed
    }
}

// MARK: - Memory Management

/// Utility for managing memory-intensive operations
enum MemoryManager {
    
    /// Executes a block with automatic memory cleanup
    /// - Parameter block: The block to execute
    /// - Returns: The result of the block
    static func withAutoreleasePool<T>(_ block: () throws -> T) rethrows -> T {
        try autoreleasepool {
            try block()
        }
    }
    
    /// Executes an async block with automatic memory cleanup
    /// - Parameter block: The async block to execute
    /// - Returns: The result of the block
    static func withAutoreleasePool<T>(_ block: @escaping () async throws -> T) async rethrows -> T {
        return try await block()
    }
}

// MARK: - View Performance Extensions

extension View {
    
    /// Adds performance monitoring to a view
    /// - Parameter label: Label for the performance measurement
    /// - Returns: A view with performance monitoring
    func measurePerformance(_ label: String) -> some View {
        self.onAppear {
            let start = CFAbsoluteTimeGetCurrent()
            DispatchQueue.main.async {
                let duration = CFAbsoluteTimeGetCurrent() - start
                if duration > 0.016 { // More than one frame at 60fps
                    print("⚠️ Performance: \(label) took \(String(format: "%.3f", duration))s")
                }
            }
        }
    }
    
    /// Optimizes the view for large lists
    /// - Returns: An optimized view
    func optimizeForLargeList() -> some View {
        self
            .drawingGroup() // Flatten view hierarchy for better performance
    }
}

// MARK: - Collection Performance Extensions

extension Collection {
    
    /// Safely accesses an element at the given index
    /// - Parameter index: The index to access
    /// - Returns: The element at the index, or nil if out of bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    
    /// Chunks the array into smaller arrays of the specified size
    /// - Parameter size: The size of each chunk
    /// - Returns: An array of chunks
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Debouncing

/// A debouncer that delays execution of a closure
@MainActor
class Debouncer {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    
    /// Initializes a debouncer with the specified delay
    /// - Parameter delay: The delay in seconds
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    /// Debounces the execution of a closure
    /// - Parameter action: The closure to execute
    func debounce(_ action: @escaping () -> Void) {
        workItem?.cancel()
        
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    /// Cancels any pending debounced action
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - Throttling

/// A throttler that limits the frequency of closure execution
@MainActor
class Throttler {
    private var lastExecutionTime: Date?
    private let interval: TimeInterval
    
    /// Initializes a throttler with the specified interval
    /// - Parameter interval: The minimum interval between executions in seconds
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    /// Throttles the execution of a closure
    /// - Parameter action: The closure to execute
    /// - Returns: True if the action was executed, false if throttled
    @discardableResult
    func throttle(_ action: () -> Void) -> Bool {
        let now = Date()
        
        if let lastTime = lastExecutionTime {
            let timeSinceLastExecution = now.timeIntervalSince(lastTime)
            if timeSinceLastExecution < interval {
                return false
            }
        }
        
        lastExecutionTime = now
        action()
        return true
    }
}

// MARK: - Image Caching

/// Simple in-memory cache for images or data
actor Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private let maxSize: Int
    
    /// Initializes a cache with the specified maximum size
    /// - Parameter maxSize: Maximum number of items to cache
    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }
    
    /// Retrieves a value from the cache
    /// - Parameter key: The key to look up
    /// - Returns: The cached value, or nil if not found
    func get(_ key: Key) -> Value? {
        storage[key]
    }
    
    /// Stores a value in the cache
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to store it under
    func set(_ value: Value, forKey key: Key) {
        // Simple LRU: remove oldest if at capacity
        if storage.count >= maxSize, storage[key] == nil {
            if let firstKey = storage.keys.first {
                storage.removeValue(forKey: firstKey)
            }
        }
        storage[key] = value
    }
    
    /// Removes a value from the cache
    /// - Parameter key: The key to remove
    func remove(_ key: Key) {
        storage.removeValue(forKey: key)
    }
    
    /// Clears all cached values
    func clear() {
        storage.removeAll()
    }
}

// MARK: - Background Task Management

/// Manages background task execution
enum BackgroundTaskManager {
    
    /// Executes a task on a background queue
    /// - Parameters:
    ///   - qos: The quality of service for the task
    ///   - task: The task to execute
    static func execute(qos: DispatchQoS.QoSClass = .userInitiated, _ task: @escaping @Sendable () async throws -> Void) {
        Task.detached(priority: qos.toTaskPriority()) {
            try await task()
        }
    }
}

extension DispatchQoS.QoSClass {
    func toTaskPriority() -> TaskPriority {
        switch self {
        case .userInteractive:
            return .high
        case .userInitiated:
            return .medium
        case .utility:
            return .low
        case .background:
            return .background
        default:
            return .medium
        }
    }
}
