@_exported import members_A
import members_B


extension X {
  public func XinC() { }

  public static func <>(a: Self, b: Self) -> Self { a }
}

extension Y {
  public func YinC() { }

  public static func <>(a: Self, b: Self) -> Self { a }
}

public enum EnumInC {
  case caseInC
}
