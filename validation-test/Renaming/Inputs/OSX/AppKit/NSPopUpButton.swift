
class NSPopUpButton : NSButton {
  init(frame buttonFrame: NSRect, pullsDown flag: Bool)
  var pullsDown: Bool
  var autoenablesItems: Bool
  var preferredEdge: NSRectEdge
  func addItem(withTitle title: String)
  func addItems(withTitles itemTitles: [String])
  func insertItem(withTitle title: String, at index: Int)
  func removeItem(withTitle title: String)
  func removeItem(at index: Int)
  func removeAllItems()
  var itemArray: [NSMenuItem] { get }
  var numberOfItems: Int { get }
  @discardableResult
  func index(of item: NSMenuItem) -> Int
  @discardableResult
  func indexOfItem(withTitle title: String) -> Int
  @discardableResult
  func indexOfItem(withTag tag: Int) -> Int
  @discardableResult
  func indexOfItem(withRepresentedObject obj: AnyObject?) -> Int
  @discardableResult
  func indexOfItem(withTarget target: AnyObject?, andAction actionSelector: Selector?) -> Int
  @discardableResult
  func item(at index: Int) -> NSMenuItem?
  @discardableResult
  func item(withTitle title: String) -> NSMenuItem?
  var lastItem: NSMenuItem? { get }
  func select(_ item: NSMenuItem?)
  func selectItem(at index: Int)
  func selectItem(withTitle title: String)
  @discardableResult
  func selectItem(withTag tag: Int) -> Bool
  var selectedItem: NSMenuItem? { get }
  var indexOfSelectedItem: Int { get }
  func synchronizeTitleAndSelectedItem()
  @discardableResult
  func itemTitle(at index: Int) -> String
  var itemTitles: [String] { get }
  var titleOfSelectedItem: String? { get }
}
struct __pbFlags {
  var needsPullsDownFromTemplate: UInt32
  var RESERVED: UInt32
  init()
  init(needsPullsDownFromTemplate needsPullsDownFromTemplate: UInt32, RESERVED RESERVED: UInt32)
}
let NSPopUpButtonWillPopUpNotification: String
