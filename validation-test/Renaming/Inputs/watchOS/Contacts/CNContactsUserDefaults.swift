
@available(watchOS 2.0, *)
class CNContactsUserDefaults : NSObject {
  @discardableResult
  class func shared() -> Self
  var sortOrder: CNContactSortOrder { get }
  var countryCode: String { get }
}
