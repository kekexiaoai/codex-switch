import Foundation

public enum MenuBarStrings {
    public enum Language {
        case english
        case simplifiedChinese
    }

    public enum Key {
        case ok
        case cancel
        case codex
        case updated
        case refreshUsage
        case switchAccount
        case currentAccount
        case removeAccount
        case removeAccountConfirmationTitle
        case remove
        case fiveHourShort
        case weeklyShort
        case continueActivation
        case confirmActivation
        case addAccount
        case importCurrentAccount
        case importBackupAuth
        case loginInBrowser
        case statusPage
        case showEmails
        case hideEmails
        case providerSync
        case settings
        case quit
        case cancelLogin
        case noAccount
        case live
        case preview
        case refreshDisabledSource
        case unavailable
        case localLogs
        case cache
        case api
        case refreshOff
        case noUsage
        case auto
        case local
        case fiveHoursTitle
        case weeklyTitle
        case browserLoginInProgressTitle
        case browserLoginInProgressMessage
        case importingCurrentAccountTitle
        case importingCurrentAccountMessage
        case cannotActivateAccountTitle
        case cannotActivateAccountMessage
        case accountRemovedTitle
        case accountRemovedMessage
        case accountRemovedNoActiveMessage
        case removeFailedTitle
        case removeFailedMessage
        case accountRefreshedTitle
        case accountRefreshedMessage
        case cannotImportCurrentAccountTitle
        case cannotImportCurrentAccountNoAuth
        case cannotImportCurrentAccountNoSession
        case cannotImportCurrentAccountInvalid
        case cannotImportCurrentAccountArchive
        case cannotImportCurrentAccountGeneric
        case cannotImportBackupAuthTitle
        case cannotImportBackupAuthUnreadable
        case cannotImportBackupAuthInvalid
        case cannotImportBackupAuthArchive
        case cannotImportBackupAuthGeneric
        case browserCouldNotOpenTitle
        case browserCouldNotOpenMessage
        case browserLoginCancelledTitle
        case browserLoginCancelledMessage
        case browserLoginTimedOutTitle
        case browserLoginTimedOutMessage
        case browserLoginFailedTitle
        case browserLoginNoSessionMessage
        case browserLoginFailedMessage
        case browserLoginGenericMessage
    }

    public static func text(_ key: Key, preferredLanguages: [String]? = nil) -> String {
        switch language(preferredLanguages: preferredLanguages) {
        case .english:
            return englishText(for: key)
        case .simplifiedChinese:
            return simplifiedChineseText(for: key)
        }
    }

    public static func updatedLabel(_ value: String, preferredLanguages: [String]? = nil) -> String {
        switch language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Updated \(value)"
        case .simplifiedChinese:
            return "更新于 \(value)"
        }
    }

    public static func accountRemovalMessage(
        emailMask: String,
        isCurrent: Bool,
        preferredLanguages: [String]? = nil
    ) -> String {
        switch language(preferredLanguages: preferredLanguages) {
        case .english:
            if isCurrent {
                return "Remove \(emailMask) from archived accounts? Because it is currently active, Codex Switch will switch to another archived account when available, or clear the current Codex session."
            }
            return "Remove \(emailMask) from archived accounts? This only deletes the archived copy stored on this Mac."
        case .simplifiedChinese:
            if isCurrent {
                return "要从归档账号中移除 \(emailMask) 吗？由于它当前处于激活状态，Codex Switch 会在可用时切换到其他归档账号，否则清空当前 Codex 会话。"
            }
            return "要从归档账号中移除 \(emailMask) 吗？这只会删除保存在这台 Mac 上的归档副本。"
        }
    }

    public static func activationConfirmationMessage(preferredLanguages: [String]? = nil) -> String {
        switch language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Current Codex auth appears to be using API key mode. Continuing will overwrite the current auth.json and switch Codex to this archived account session."
        case .simplifiedChinese:
            return "检测到当前 Codex auth 似乎正在使用 API Key 模式。继续操作将覆盖当前 auth.json，并把 Codex 切换到这个归档账号会话。"
        }
    }

    public static func resetsLabel(_ value: String, preferredLanguages: [String]? = nil) -> String {
        switch language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Resets \(value)"
        case .simplifiedChinese:
            return "重置于 \(value)"
        }
    }

    public static func usageSourceSummary(_ value: String, preferredLanguages: [String]? = nil) -> String {
        switch language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Usage source: \(value)"
        case .simplifiedChinese:
            return "用量来源：\(value)"
        }
    }

    public static func usageSourceLabel(_ value: String, preferredLanguages: [String]? = nil) -> String {
        switch value {
        case "API":
            return text(.api, preferredLanguages: preferredLanguages)
        case "Local Logs":
            return text(.localLogs, preferredLanguages: preferredLanguages)
        case "Cache":
            return text(.cache, preferredLanguages: preferredLanguages)
        case "Refresh Disabled":
            return text(.refreshDisabledSource, preferredLanguages: preferredLanguages)
        case "Unavailable":
            return text(.unavailable, preferredLanguages: preferredLanguages)
        default:
            return value
        }
    }

    static func language(preferredLanguages: [String]? = nil) -> Language {
        let languages = preferredLanguages ?? defaultPreferredLanguages()
        guard let first = languages.first?.lowercased() else {
            return .english
        }

        if first.hasPrefix("zh") {
            return .simplifiedChinese
        }

        return .english
    }

    private static func defaultPreferredLanguages() -> [String] {
        if NSClassFromString("XCTestCase") != nil {
            return ["en"]
        }
        return Locale.preferredLanguages
    }

    private static func englishText(for key: Key) -> String {
        switch key {
        case .ok: return "OK"
        case .cancel: return "Cancel"
        case .codex: return "Codex"
        case .updated: return "Updated"
        case .refreshUsage: return "Refresh Usage"
        case .switchAccount: return "Switch Account"
        case .currentAccount: return "Current Account"
        case .removeAccount: return "Remove Account"
        case .removeAccountConfirmationTitle: return "Remove Account?"
        case .remove: return "Remove"
        case .fiveHourShort: return "5h"
        case .weeklyShort: return "wk"
        case .continueActivation: return "Continue Activation"
        case .confirmActivation: return "Confirm Activation"
        case .addAccount: return "Add Account"
        case .importCurrentAccount: return "Import Current Account"
        case .importBackupAuth: return "Import Backup Auth"
        case .loginInBrowser: return "Login in Browser"
        case .statusPage: return "Status Page"
        case .showEmails: return "Show Emails"
        case .hideEmails: return "Hide Emails"
        case .providerSync: return "Provider Sync"
        case .settings: return "Settings"
        case .quit: return "Quit"
        case .cancelLogin: return "Cancel Login"
        case .noAccount: return "No account"
        case .live: return "Live"
        case .preview: return "Preview"
        case .refreshDisabledSource: return "Refresh Disabled"
        case .unavailable: return "Unavailable"
        case .localLogs: return "Local Logs"
        case .cache: return "Cache"
        case .api: return "API"
        case .refreshOff: return "Refresh off"
        case .noUsage: return "No usage"
        case .auto: return "Auto"
        case .local: return "Local"
        case .fiveHoursTitle: return "5 Hours"
        case .weeklyTitle: return "Weekly"
        case .browserLoginInProgressTitle: return "Browser Login In Progress"
        case .browserLoginInProgressMessage: return "Complete the sign-in flow in your browser. You can cancel here and try again at any time."
        case .importingCurrentAccountTitle: return "Importing Current Account"
        case .importingCurrentAccountMessage: return "Reading your current Codex auth and adding it to Codex Switch."
        case .cannotActivateAccountTitle: return "Cannot Activate Account"
        case .cannotActivateAccountMessage: return "Activating the archived account failed. Please try again."
        case .accountRemovedTitle: return "Account Removed"
        case .accountRemovedMessage: return "The archived account was removed."
        case .accountRemovedNoActiveMessage: return "The archived account was removed and there is no remaining active account."
        case .removeFailedTitle: return "Remove Failed"
        case .removeFailedMessage: return "Removing the archived account failed. Please try again."
        case .accountRefreshedTitle: return "Account Refreshed"
        case .accountRefreshedMessage: return "Account already exists, auth refreshed."
        case .cannotImportCurrentAccountTitle: return "Cannot Import Current Account"
        case .cannotImportCurrentAccountNoAuth: return "No current Codex auth.json was found. Log in with Codex first, or import a backup auth.json."
        case .cannotImportCurrentAccountNoSession: return "Current Codex auth does not contain a browser login session. If this machine is using OPENAI_API_KEY mode, choose Login in Browser or import a backup auth.json."
        case .cannotImportCurrentAccountInvalid: return "The current Codex auth.json is not a valid browser auth file."
        case .cannotImportCurrentAccountArchive: return "Codex Switch could not archive the current auth file into ~/.codex/accounts/."
        case .cannotImportCurrentAccountGeneric: return "Current account import failed. Please try again."
        case .cannotImportBackupAuthTitle: return "Cannot Import Backup Auth"
        case .cannotImportBackupAuthUnreadable: return "The selected auth.json could not be read."
        case .cannotImportBackupAuthInvalid: return "The selected auth.json does not contain a valid browser login session."
        case .cannotImportBackupAuthArchive: return "Codex Switch could not archive the selected auth.json into ~/.codex/accounts/."
        case .cannotImportBackupAuthGeneric: return "Backup auth import failed. Please try again."
        case .browserCouldNotOpenTitle: return "Browser Could Not Open"
        case .browserCouldNotOpenMessage: return "Codex Switch could not open your default browser. Check your browser settings, then review ~/.codex/codex-switch/browser-login.log and try again."
        case .browserLoginCancelledTitle: return "Browser Login Cancelled"
        case .browserLoginCancelledMessage: return "Codex browser login was cancelled before a valid auth session was created."
        case .browserLoginTimedOutTitle: return "Browser Login Timed Out"
        case .browserLoginTimedOutMessage: return "The browser sign-in did not finish before timing out. Try Login in Browser again."
        case .browserLoginFailedTitle: return "Browser Login Failed"
        case .browserLoginNoSessionMessage: return "Codex login finished, but no valid browser auth session was created. Complete the browser flow and try again."
        case .browserLoginFailedMessage: return "Codex browser login did not complete. Complete the browser sign-in and try again."
        case .browserLoginGenericMessage: return "Browser login failed. Please try again."
        }
    }

    private static func simplifiedChineseText(for key: Key) -> String {
        switch key {
        case .ok: return "确定"
        case .cancel: return "取消"
        case .codex: return "Codex"
        case .updated: return "更新于"
        case .refreshUsage: return "刷新用量"
        case .switchAccount: return "切换账号"
        case .currentAccount: return "当前账号"
        case .removeAccount: return "移除账号"
        case .removeAccountConfirmationTitle: return "移除账号？"
        case .remove: return "移除"
        case .fiveHourShort: return "5小时"
        case .weeklyShort: return "周"
        case .continueActivation: return "继续激活"
        case .confirmActivation: return "确认激活"
        case .addAccount: return "添加账号"
        case .importCurrentAccount: return "导入当前账号"
        case .importBackupAuth: return "导入备份 Auth"
        case .loginInBrowser: return "浏览器登录"
        case .statusPage: return "状态页"
        case .showEmails: return "显示邮箱"
        case .hideEmails: return "隐藏邮箱"
        case .providerSync: return "Provider 同步"
        case .settings: return "设置"
        case .quit: return "退出"
        case .cancelLogin: return "取消登录"
        case .noAccount: return "暂无账号"
        case .live: return "实时"
        case .preview: return "预览"
        case .refreshDisabledSource: return "已关闭刷新"
        case .unavailable: return "不可用"
        case .localLogs: return "本地日志"
        case .cache: return "缓存"
        case .api: return "接口"
        case .refreshOff: return "已关闭刷新"
        case .noUsage: return "暂无用量"
        case .auto: return "自动"
        case .local: return "本地"
        case .fiveHoursTitle: return "5 小时"
        case .weeklyTitle: return "每周"
        case .browserLoginInProgressTitle: return "浏览器登录进行中"
        case .browserLoginInProgressMessage: return "请在浏览器中完成登录流程。你也可以在这里取消，稍后再试。"
        case .importingCurrentAccountTitle: return "正在导入当前账号"
        case .importingCurrentAccountMessage: return "正在读取当前 Codex auth，并将其添加到 Codex Switch。"
        case .cannotActivateAccountTitle: return "无法激活账号"
        case .cannotActivateAccountMessage: return "激活归档账号失败，请重试。"
        case .accountRemovedTitle: return "账号已移除"
        case .accountRemovedMessage: return "归档账号已移除。"
        case .accountRemovedNoActiveMessage: return "归档账号已移除，且没有剩余可激活账号。"
        case .removeFailedTitle: return "移除失败"
        case .removeFailedMessage: return "移除归档账号失败，请重试。"
        case .accountRefreshedTitle: return "账号已刷新"
        case .accountRefreshedMessage: return "账号已存在，认证信息已刷新。"
        case .cannotImportCurrentAccountTitle: return "无法导入当前账号"
        case .cannotImportCurrentAccountNoAuth: return "未找到当前 Codex 的 auth.json。请先用 Codex 登录，或导入备份 auth.json。"
        case .cannotImportCurrentAccountNoSession: return "当前 Codex auth 不包含浏览器登录会话。如果这台机器正在使用 OPENAI_API_KEY 模式，请选择“浏览器登录”或导入备份 auth.json。"
        case .cannotImportCurrentAccountInvalid: return "当前 Codex auth.json 不是有效的浏览器认证文件。"
        case .cannotImportCurrentAccountArchive: return "Codex Switch 无法将当前 auth 文件归档到 ~/.codex/accounts/。"
        case .cannotImportCurrentAccountGeneric: return "导入当前账号失败，请重试。"
        case .cannotImportBackupAuthTitle: return "无法导入备份 Auth"
        case .cannotImportBackupAuthUnreadable: return "无法读取所选 auth.json。"
        case .cannotImportBackupAuthInvalid: return "所选 auth.json 不包含有效的浏览器登录会话。"
        case .cannotImportBackupAuthArchive: return "Codex Switch 无法将所选 auth.json 归档到 ~/.codex/accounts/。"
        case .cannotImportBackupAuthGeneric: return "导入备份 Auth 失败，请重试。"
        case .browserCouldNotOpenTitle: return "无法打开浏览器"
        case .browserCouldNotOpenMessage: return "Codex Switch 无法打开默认浏览器。请检查浏览器设置，然后查看 ~/.codex/codex-switch/browser-login.log 后重试。"
        case .browserLoginCancelledTitle: return "浏览器登录已取消"
        case .browserLoginCancelledMessage: return "在创建有效认证会话之前，Codex 浏览器登录已被取消。"
        case .browserLoginTimedOutTitle: return "浏览器登录超时"
        case .browserLoginTimedOutMessage: return "浏览器登录未在超时时间内完成，请再次尝试“浏览器登录”。"
        case .browserLoginFailedTitle: return "浏览器登录失败"
        case .browserLoginNoSessionMessage: return "Codex 登录流程已结束，但没有创建有效的浏览器认证会话。请完成浏览器流程后重试。"
        case .browserLoginFailedMessage: return "Codex 浏览器登录未完成。请在浏览器中完成登录后重试。"
        case .browserLoginGenericMessage: return "浏览器登录失败，请重试。"
        }
    }
}
