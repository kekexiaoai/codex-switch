import Foundation

public enum MenuBarHostKind {
    case statusItemPopover
    case menuBarExtra

    public static var current: MenuBarHostKind {
        if #available(macOS 13, *) {
            return .menuBarExtra
        }

        return .statusItemPopover
    }
}
