# macOS 외부 앱 메뉴바 아이콘 제어 구현 가이드

## 목차
1. [개요](#개요)
2. [기술 배경](#기술-배경)
3. [구현 방법](#구현-방법)
4. [코드 예제](#코드-예제)
5. [주의사항](#주의사항)
6. [참고자료](#참고자료)

## 개요

macOS에서 외부 앱의 메뉴바 아이콘(NSStatusItem)을 프로그래밍적으로 클릭하는 기능을 구현하는 방법에 대한 기술 문서입니다. 이 기능은 음성 명령으로 메뉴바 앱을 제어하거나, 자동화 스크립트를 작성할 때 유용합니다.

### 주요 목표
- 외부 앱의 메뉴바 아이콘을 프로그래밍적으로 찾기
- 해당 아이콘을 클릭하여 메뉴 표시
- Swift와 Accessibility API를 사용한 구현

## 기술 배경

### NSStatusItem과 메뉴바 구조

macOS의 메뉴바는 다음과 같은 구조로 구성됩니다:

1. **Application Menus** (왼쪽): 현재 활성 앱의 메뉴
2. **Status Items** (오른쪽): NSStatusItem으로 생성된 시스템 및 앱 아이콘
3. **Menu Extras** (오른쪽 끝): 시스템이 관리하는 특별한 메뉴 아이템

```
[Apple] [App Menu] [File] [Edit] ... [공백] ... [앱 아이콘들] [Wi-Fi] [배터리] [시계]
```

### SystemUIServer 프로세스

- 메뉴바의 오른쪽 영역(Status Items, Menu Extras)은 `SystemUIServer` 프로세스가 관리
- Accessibility API를 통해 이 프로세스에 접근하여 메뉴바 아이템 제어 가능

## 구현 방법

### 방법 1: Accessibility API 직접 사용 (권장)

#### 1.1 필요한 권한 확인

```swift
import ApplicationServices

func checkAccessibilityPermission() -> Bool {
    let checkOptionKey = kAXTrustedCheckOptionPrompt.takeRetainedValue()
    let options = [checkOptionKey: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
```

#### 1.2 SystemUIServer 프로세스 접근

```swift
func getSystemUIServerElement() -> AXUIElement? {
    // SystemUIServer 프로세스 찾기
    let apps = NSWorkspace.shared.runningApplications
    guard let systemUIServer = apps.first(where: { 
        $0.bundleIdentifier == "com.apple.systemuiserver" 
    }) else {
        return nil
    }
    
    return AXUIElementCreateApplication(systemUIServer.processIdentifier)
}
```

#### 1.3 메뉴바 아이템 가져오기

```swift
func getMenuBarItems() -> [AXUIElement] {
    guard let systemUIServer = getSystemUIServerElement() else { 
        return [] 
    }
    
    // 메뉴바 가져오기
    var menuBarRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
        systemUIServer, 
        kAXExtrasMenuBarAttribute as CFString,  // 또는 "AXMenuBar"
        &menuBarRef
    )
    
    guard result == .success,
          let menuBar = menuBarRef as! AXUIElement? else {
        return []
    }
    
    // 메뉴바 아이템들 가져오기
    var childrenRef: CFTypeRef?
    AXUIElementCopyAttributeValue(
        menuBar,
        kAXChildrenAttribute as CFString,
        &childrenRef
    )
    
    return (childrenRef as? [AXUIElement]) ?? []
}
```

#### 1.4 특정 메뉴바 아이템 찾기

```swift
func findMenuBarItem(withTitle title: String) -> AXUIElement? {
    let items = getMenuBarItems()
    
    for item in items {
        // Title 속성 확인
        var titleRef: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            item,
            kAXTitleAttribute as CFString,
            &titleRef
        )
        
        if titleResult == .success,
           let itemTitle = titleRef as? String,
           itemTitle == title {
            return item
        }
        
        // Description 속성도 확인
        var descRef: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(
            item,
            kAXDescriptionAttribute as CFString,
            &descRef
        )
        
        if descResult == .success,
           let itemDesc = descRef as? String,
           itemDesc.contains(title) {
            return item
        }
    }
    
    return nil
}
```

#### 1.5 메뉴바 아이템 클릭

```swift
func clickMenuBarItem(_ element: AXUIElement) -> Bool {
    // 방법 1: AXPress 액션 사용
    let result = AXUIElementPerformAction(
        element,
        kAXPressAction as CFString
    )
    
    if result == .success {
        return true
    }
    
    // 방법 2: 위치를 찾아서 마우스 클릭 시뮬레이션
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    
    AXUIElementCopyAttributeValue(
        element,
        kAXPositionAttribute as CFString,
        &positionRef
    )
    
    AXUIElementCopyAttributeValue(
        element,
        kAXSizeAttribute as CFString,
        &sizeRef
    )
    
    if let positionValue = positionRef,
       let sizeValue = sizeRef {
        var position = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        
        // 중앙 위치 계산
        let clickPoint = CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
        
        // 마우스 클릭 이벤트 생성
        simulateClick(at: clickPoint)
        return true
    }
    
    return false
}

func simulateClick(at point: CGPoint) {
    // 마우스 이동
    let moveEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )
    moveEvent?.post(tap: .cghidEventTap)
    
    // 마우스 클릭
    let clickDown = CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    )
    
    let clickUp = CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    )
    
    clickDown?.post(tap: .cghidEventTap)
    usleep(50_000) // 0.05초 대기
    clickUp?.post(tap: .cghidEventTap)
}
```

### 방법 2: AppleScript 브리지 사용

```swift
import Foundation

class MenuBarAppleScriptController {
    
    func clickMenuBarItem(named itemName: String) throws {
        let script = """
        tell application "System Events"
            tell process "SystemUIServer"
                set menuBarItems to menu bar items of menu bar 1
                repeat with aItem in menuBarItems
                    if (description of aItem) contains "\(itemName)" then
                        click aItem
                        return true
                    end if
                end repeat
            end tell
        end tell
        return false
        """
        
        guard let appleScript = NSAppleScript(source: script) else {
            throw MenuBarError.scriptCreationFailed
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            throw MenuBarError.scriptExecutionFailed(error)
        }
        
        guard result.booleanValue else {
            throw MenuBarError.itemNotFound
        }
    }
    
    func getMenuBarItemTitles() throws -> [String] {
        let script = """
        tell application "System Events"
            tell process "SystemUIServer"
                set itemTitles to {}
                set menuBarItems to menu bar items of menu bar 1
                repeat with aItem in menuBarItems
                    try
                        set itemTitle to title of aItem
                        set end of itemTitles to itemTitle
                    on error
                        try
                            set itemDesc to description of aItem
                            set end of itemTitles to itemDesc
                        end try
                    end try
                end repeat
                return itemTitles
            end tell
        end tell
        """
        
        guard let appleScript = NSAppleScript(source: script) else {
            throw MenuBarError.scriptCreationFailed
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            throw MenuBarError.scriptExecutionFailed(error)
        }
        
        // AppleScript 리스트를 Swift 배열로 변환
        var titles: [String] = []
        for i in 1...result.numberOfItems {
            if let item = result.atIndex(i),
               let title = item.stringValue {
                titles.append(title)
            }
        }
        
        return titles
    }
}

enum MenuBarError: LocalizedError {
    case scriptCreationFailed
    case scriptExecutionFailed(NSDictionary)
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            return "Failed to create AppleScript"
        case .scriptExecutionFailed(let error):
            return "Script execution failed: \(error)"
        case .itemNotFound:
            return "Menu bar item not found"
        }
    }
}
```

### 방법 3: 하이브리드 접근 (Accessibility + CGEvent)

```swift
class MenuBarController {
    
    /// 메뉴바 아이템의 위치를 찾아서 클릭
    func clickMenuBarItemByPosition(containing keyword: String) -> Bool {
        // 1. 모든 메뉴바 아이템 위치 스캔
        let menuBarHeight: CGFloat = 25  // macOS 메뉴바 높이
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        
        // 오른쪽부터 스캔 (Status Items 영역)
        for x in stride(from: screenWidth - 50, to: screenWidth / 2, by: -30) {
            let point = CGPoint(x: x, y: menuBarHeight / 2)
            
            // 해당 위치의 UI 요소 가져오기
            var element: AXUIElement?
            let result = AXUIElementCopyElementAtPosition(
                AXUIElementCreateSystemWide(),
                Float(point.x),
                Float(point.y),
                &element
            )
            
            if result == .success, let element = element {
                // 요소의 설명 확인
                if let description = getElementDescription(element),
                   description.contains(keyword) {
                    // 클릭 수행
                    simulateClick(at: point)
                    return true
                }
            }
        }
        
        return false
    }
    
    private func getElementDescription(_ element: AXUIElement) -> String? {
        var descRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXDescriptionAttribute as CFString,
            &descRef
        )
        
        if result == .success {
            return descRef as? String
        }
        
        // Title도 확인
        var titleRef: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            element,
            kAXTitleAttribute as CFString,
            &titleRef
        )
        
        if titleResult == .success {
            return titleRef as? String
        }
        
        return nil
    }
}
```

## 코드 예제

### 완전한 구현 예제

```swift
import Foundation
import ApplicationServices
import AppKit

@MainActor
class MenuBarAutomation {
    
    // MARK: - Properties
    
    private let appleScriptController = MenuBarAppleScriptController()
    
    // MARK: - Public Methods
    
    /// 특정 앱의 메뉴바 아이콘 클릭
    func clickAppMenuBarIcon(appName: String) async throws {
        // 1. 권한 확인
        guard checkAccessibilityPermission() else {
            throw MenuBarError.accessibilityNotAuthorized
        }
        
        // 2. 여러 방법 시도
        
        // 방법 1: Accessibility API
        if let element = findMenuBarItem(withTitle: appName) {
            if clickMenuBarItem(element) {
                return
            }
        }
        
        // 방법 2: AppleScript
        do {
            try appleScriptController.clickMenuBarItem(named: appName)
            return
        } catch {
            print("AppleScript method failed: \(error)")
        }
        
        // 방법 3: 위치 기반 클릭
        if clickMenuBarItemByPosition(containing: appName) {
            return
        }
        
        throw MenuBarError.itemNotFound
    }
    
    /// 모든 메뉴바 아이템 목록 가져오기
    func getAllMenuBarItems() async throws -> [String] {
        var items: [String] = []
        
        // Accessibility API로 시도
        let axItems = getMenuBarItems()
        for item in axItems {
            if let title = getElementTitle(item) {
                items.append(title)
            } else if let desc = getElementDescription(item) {
                items.append(desc)
            }
        }
        
        // AppleScript로 추가 정보 수집
        if let scriptItems = try? appleScriptController.getMenuBarItemTitles() {
            items.append(contentsOf: scriptItems)
        }
        
        // 중복 제거
        return Array(Set(items)).sorted()
    }
    
    // MARK: - Private Helper Methods
    
    private func getElementTitle(_ element: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXTitleAttribute as CFString,
            &titleRef
        )
        return result == .success ? titleRef as? String : nil
    }
    
    private func getElementDescription(_ element: AXUIElement) -> String? {
        var descRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXDescriptionAttribute as CFString,
            &descRef
        )
        return result == .success ? descRef as? String : nil
    }
}

// MARK: - Error Types

enum MenuBarError: LocalizedError {
    case accessibilityNotAuthorized
    case itemNotFound
    case scriptCreationFailed
    case scriptExecutionFailed(NSDictionary)
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotAuthorized:
            return "Accessibility permission is required to control menu bar items"
        case .itemNotFound:
            return "Menu bar item not found"
        case .scriptCreationFailed:
            return "Failed to create AppleScript"
        case .scriptExecutionFailed(let error):
            return "Script execution failed: \(error)"
        }
    }
}
```

### 사용 예제

```swift
// 사용 예제
class MenuBarVoiceControl {
    
    let menuBarAutomation = MenuBarAutomation()
    
    func handleVoiceCommand(_ command: String) async {
        // "Open Dropbox menu" 같은 명령 처리
        if command.contains("menu") {
            let appName = extractAppName(from: command)
            
            do {
                try await menuBarAutomation.clickAppMenuBarIcon(appName: appName)
                print("✅ Successfully clicked \(appName) menu bar icon")
            } catch {
                print("❌ Failed to click menu bar icon: \(error)")
            }
        }
    }
    
    func listAllMenuBarItems() async {
        do {
            let items = try await menuBarAutomation.getAllMenuBarItems()
            print("📋 Available menu bar items:")
            items.forEach { print("  - \($0)") }
        } catch {
            print("❌ Failed to list menu bar items: \(error)")
        }
    }
}
```

## 주의사항

### 1. 권한 요구사항

- **Accessibility 권한 필수**: 시스템 환경설정 > 보안 및 개인정보 보호 > 손쉬운 사용에서 앱 추가
- **App Sandbox 비활성화**: `com.apple.security.app-sandbox = false`
- **Automation 권한**: AppleScript 사용 시 필요

### 2. 기술적 제한사항

#### 메뉴바 아이템 식별의 어려움
- 모든 메뉴바 아이템이 고유한 title이나 identifier를 가지지 않음
- 일부 앱은 이미지만 사용하여 텍스트 식별이 불가능
- 동적으로 변경되는 아이템 (예: 배터리 퍼센트)

#### 시스템 버전별 차이
- macOS 10.10 이후 NSStatusItem의 button 속성 도입
- macOS 13.0+ MenuBarExtra SwiftUI API 추가
- 각 버전마다 Accessibility API 동작이 미묘하게 다름

#### 타이밍 이슈
- 클릭 후 메뉴가 나타나기까지 지연 시간 필요
- 너무 빠른 연속 클릭은 무시될 수 있음

### 3. 보안 고려사항

- 사용자에게 명확한 권한 요청 UI 제공
- 악용 가능성이 있는 기능이므로 사용 목적 명시
- App Store 배포 시 제한될 가능성 높음

### 4. 성능 최적화

```swift
// 메뉴바 아이템 캐싱
class MenuBarCache {
    private var cache: [String: AXUIElement] = [:]
    private var lastUpdate: Date = Date()
    private let cacheTimeout: TimeInterval = 5.0
    
    func getCachedItem(for key: String) -> AXUIElement? {
        if Date().timeIntervalSince(lastUpdate) > cacheTimeout {
            cache.removeAll()
            return nil
        }
        return cache[key]
    }
    
    func setCachedItem(_ element: AXUIElement, for key: String) {
        cache[key] = element
        lastUpdate = Date()
    }
}
```

## 참고자료

### Apple 공식 문서
- [Accessibility Programming Guide for OS X](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [AXUIElement.h Reference](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [NSStatusItem Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [MenuBarExtra SwiftUI](https://developer.apple.com/documentation/swiftui/menubarextra)

### 관련 GitHub 프로젝트
- [DFAXUIElement](https://github.com/DevilFinger/DFAXUIElement) - Accessibility API Swift 래퍼
- [SwiftBar](https://github.com/swiftbar/SwiftBar) - 메뉴바 커스터마이징 도구
- [alt-tab-macos](https://github.com/lwouis/alt-tab-macos) - Accessibility API 활용 예제

### 참고 문서 및 블로그
- [Building a MacOS Menu Bar App with Swift (2024)](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift-d6e293cd48eb)
- [Implementing Left Click and Right Click for Menu Bar Status Button (2024)](https://medium.com/@clyapp/implementing-left-click-and-right-click-for-menu-bar-status-button-in-macos-app-c3fc0b981cf0)
- [Tutorial: Add a Menu Bar Extra to a macOS App (8th Light)](https://8thlight.com/insights/tutorial-add-a-menu-bar-extra-to-a-macos-app)

### Stack Overflow 참고 답변
- [How to simulate a click in another application's menu](https://stackoverflow.com/questions/39215361/how-to-simulate-a-click-in-another-application-s-menu)
- [Accessing third party menu extras via AppleScript](https://stackoverflow.com/questions/11081532/accesing-third-party-menu-extras-menulets-via-applescript)
- [Swift: press button in external app via accessibility](https://stackoverflow.com/questions/72674287/swift-press-button-in-external-app-via-accessibility)

## 업데이트 이력

- 2025년 1월: 최초 작성
- macOS 15.0 및 Swift 6.1 기준
- Accessibility API 및 AppleScript 활용 방법 정리