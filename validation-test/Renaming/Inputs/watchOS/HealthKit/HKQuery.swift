
@available(watchOS 2.0, *)
class HKQuery : NSObject {
  @available(watchOS 2.2, *)
  var objectType: HKObjectType? { get }
  @available(watchOS 2.0, *)
  @available(watchOS, deprecated: 2.2, message: "Use objectType")
  var sampleType: HKSampleType? { get }
  var predicate: NSPredicate? { get }
}
@available(watchOS 2.0, *)
struct HKQueryOptions : OptionSet {
  init(rawValue rawValue: UInt)
  let rawValue: UInt
  static var strictStartDate: HKQueryOptions { get }
  static var strictEndDate: HKQueryOptions { get }
}
extension HKQuery {
  @discardableResult
  class func predicateForObjects(withMetadataKey key: String) -> NSPredicate
  @discardableResult
  class func predicateForObjects(withMetadataKey key: String, allowedValues allowedValues: [AnyObject]) -> NSPredicate
  @discardableResult
  class func predicateForObjects(withMetadataKey key: String, operatorType operatorType: NSPredicateOperatorType, value value: AnyObject) -> NSPredicate
  @discardableResult
  class func predicateForObjects(from source: HKSource) -> NSPredicate
  @discardableResult
  class func predicateForObjects(from sources: Set<HKSource>) -> NSPredicate
  @available(watchOS 2.0, *)
  @discardableResult
  class func predicateForObjects(from sourceRevisions: Set<HKSourceRevision>) -> NSPredicate
  @available(watchOS 2.0, *)
  @discardableResult
  class func predicateForObjects(from devices: Set<HKDevice>) -> NSPredicate
  @available(watchOS 2.0, *)
  @discardableResult
  class func predicateForObjects(withDeviceProperty key: String, allowedValues allowedValues: Set<String>) -> NSPredicate
  @discardableResult
  class func predicateForObject(with UUID: NSUUID) -> NSPredicate
  @discardableResult
  class func predicateForObjects(with UUIDs: Set<NSUUID>) -> NSPredicate
  @discardableResult
  class func predicateForObjectsWithNoCorrelation() -> NSPredicate
  @discardableResult
  class func predicateForObjects(from workout: HKWorkout) -> NSPredicate
}
extension HKQuery {
  @discardableResult
  class func predicateForSamples(withStart startDate: NSDate?, end endDate: NSDate?, options options: HKQueryOptions = []) -> NSPredicate
}
extension HKQuery {
  @discardableResult
  class func predicateForQuantitySamples(with operatorType: NSPredicateOperatorType, quantity quantity: HKQuantity) -> NSPredicate
}
extension HKQuery {
  @discardableResult
  class func predicateForCategorySamples(with operatorType: NSPredicateOperatorType, value value: Int) -> NSPredicate
}
extension HKQuery {
  @discardableResult
  class func predicateForWorkouts(with workoutActivityType: HKWorkoutActivityType) -> NSPredicate
  @discardableResult
  class func predicateForWorkouts(with operatorType: NSPredicateOperatorType, duration duration: NSTimeInterval) -> NSPredicate
  @discardableResult
  class func predicateForWorkouts(with operatorType: NSPredicateOperatorType, totalEnergyBurned totalEnergyBurned: HKQuantity) -> NSPredicate
  @discardableResult
  class func predicateForWorkouts(with operatorType: NSPredicateOperatorType, totalDistance totalDistance: HKQuantity) -> NSPredicate
}
extension HKQuery {
  @available(watchOS 2.2, *)
  @discardableResult
  class func predicateForActivitySummary(with dateComponents: NSDateComponents) -> NSPredicate
  @available(watchOS 2.2, *)
  @discardableResult
  class func predicate(forActivitySummariesBetweenStart startDateComponents: NSDateComponents, end endDateComponents: NSDateComponents) -> NSPredicate
}
