import Foundation

public enum MenuBarHostKind {
    case statusItemPopover
    case menuBarExtra

    public static var preferred: MenuBarHostKind {
        if #available(macOS 13, *) {
            return .menuBarExtra
        }

        return .statusItemPopover
    }

    public static var current: MenuBarHostKind {
        .statusItemPopover
    }
}
