import Foundation
import HealthKit

final class HealthKitManager {
    enum HealthKitConfigError: LocalizedError {
        case missingUsageDescriptions

        var errorDescription: String? {
            switch self {
            case .missingUsageDescriptions:
                return "Missing NSHealthShareUsageDescription / NSHealthUpdateUsageDescription in Info.plist."
            }
        }
    }

    private let healthStore = HKHealthStore()
    private let syncVersion = 1

    func requestAuthorization(for metrics: Set<SyncMetric>) async throws {
        let hasShareDescription = Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") as? String
        let hasUpdateDescription = Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") as? String
        if (hasShareDescription?.isEmpty ?? true) || (hasUpdateDescription?.isEmpty ?? true) {
            throw HealthKitConfigError.missingUsageDescriptions
        }
        let writeTypes = Set(metrics.compactMap { hkType(for: $0) })
        guard !writeTypes.isEmpty else { return }
        try await healthStore.requestAuthorization(toShare: writeTypes, read: [])
    }

    func saveBodyWeight(kg: Double, date: Date, syncID: String) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        let unit = HKUnit.gramUnit(with: .kilo)
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: kg),
            start: date,
            end: date,
            metadata: metadata(syncID: syncID)
        )
        try await healthStore.save(sample)
    }

    func saveBodyFat(percentage: Double, date: Date, syncID: String) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .percent(), doubleValue: percentage / 100.0),
            start: date,
            end: date,
            metadata: metadata(syncID: syncID)
        )
        try await healthStore.save(sample)
    }

    func saveSteps(_ count: Double, start: Date, end: Date, syncID: String) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .count(), doubleValue: count),
            start: start,
            end: end,
            metadata: metadata(syncID: syncID)
        )
        try await healthStore.save(sample)
    }

    func saveRestingHeartRate(_ bpm: Double, date: Date, syncID: String) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: bpm),
            start: date,
            end: date,
            metadata: metadata(syncID: syncID)
        )
        try await healthStore.save(sample)
    }

    func saveActiveEnergy(kcal: Double, start: Date, end: Date, syncID: String) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            start: start,
            end: end,
            metadata: metadata(syncID: syncID)
        )
        try await healthStore.save(sample)
    }

    func saveSleep(start: Date, end: Date, syncID: String) async throws {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let sample = HKCategorySample(
            type: type,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: start,
            end: end,
            metadata: metadata(syncID: syncID)
        )
        try await healthStore.save(sample)
    }

    private func hkType(for metric: SyncMetric) -> HKSampleType? {
        switch metric {
        case .bodyWeight:
            return HKObjectType.quantityType(forIdentifier: .bodyMass)
        case .bodyFat:
            return HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)
        case .steps:
            return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .sleep:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .restingHeartRate:
            return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .activeEnergy:
            return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        }
    }

    private func metadata(syncID: String) -> [String: Any] {
        [
            HKMetadataKeySyncIdentifier: syncID,
            HKMetadataKeySyncVersion: syncVersion
        ]
    }
}
