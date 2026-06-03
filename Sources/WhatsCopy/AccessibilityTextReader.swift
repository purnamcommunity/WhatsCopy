import ApplicationServices
import Foundation

public protocol SelectedTextReading {
    func selectedTextForFrontmostApplication(processIdentifier: pid_t) -> String?
}

public final class AccessibilityTextReader: SelectedTextReading {
    private let maximumDescendantCandidates = 24

    public init() {}

    public func selectedTextForFrontmostApplication(processIdentifier: pid_t) -> String? {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)

        guard let focusedElement = copyElementAttribute(
            from: applicationElement,
            attribute: kAXFocusedUIElementAttribute
        ) else {
            return nil
        }

        for element in candidateElements(startingAt: focusedElement) {
            if let selectedText = selectedText(from: element) {
                return selectedText
            }
        }

        return nil
    }

    private func candidateElements(startingAt focusedElement: AXUIElement) -> [AXUIElement] {
        var candidates = [focusedElement]

        if let parent = copyElementAttribute(from: focusedElement, attribute: kAXParentAttribute) {
            candidates.append(parent)
        }

        candidates.append(contentsOf: descendantElements(startingAt: focusedElement))
        return candidates
    }

    private func descendantElements(startingAt element: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue = copyElementArrayAttribute(from: element, attribute: kAXChildrenAttribute) ?? []

        while !queue.isEmpty && result.count < maximumDescendantCandidates {
            let child = queue.removeFirst()
            result.append(child)

            if let grandchildren = copyElementArrayAttribute(
                from: child,
                attribute: kAXChildrenAttribute
            ) {
                queue.append(contentsOf: grandchildren)
            }
        }

        return result
    }

    private func selectedText(from element: AXUIElement) -> String? {
        if let selectedText = selectedTextAttribute(from: element) {
            return selectedText
        }

        if let selectedText = selectedTextFromAXRange(from: element) {
            return selectedText
        }

        return selectedTextFromValueAndRange(from: element)
    }

    private func selectedTextAttribute(from element: AXUIElement) -> String? {
        guard let text = copyStringAttribute(
            from: element,
            attribute: kAXSelectedTextAttribute
        ) else {
            return nil
        }

        return text.isEmpty ? nil : text
    }

    private func selectedTextFromAXRange(from element: AXUIElement) -> String? {
        guard let rangeValue = copyAXValueAttribute(
            from: element,
            attribute: kAXSelectedTextRangeAttribute
        ) else {
            return nil
        }

        guard let range = cfRange(from: rangeValue), range.length > 0 else {
            return nil
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        )

        guard error == .success, let text = value as? String, !text.isEmpty else {
            return nil
        }

        return text
    }

    private func selectedTextFromValueAndRange(from element: AXUIElement) -> String? {
        guard let text = copyStringAttribute(from: element, attribute: kAXValueAttribute),
              let rangeValue = copyAXValueAttribute(
                from: element,
                attribute: kAXSelectedTextRangeAttribute
              ),
              let range = cfRange(from: rangeValue),
              range.length > 0 else {
            return nil
        }

        let nsRange = NSRange(location: range.location, length: range.length)
        guard let stringRange = Range(nsRange, in: text) else {
            return nil
        }

        let selectedText = String(text[stringRange])
        return selectedText.isEmpty ? nil : selectedText
    }

    private func copyStringAttribute(from element: AXUIElement, attribute: String) -> String? {
        copyAttribute(from: element, attribute: attribute) as? String
    }

    private func copyElementAttribute(from element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(from: element, attribute: attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func copyAXValueAttribute(from element: AXUIElement, attribute: String) -> AXValue? {
        guard let value = copyAttribute(from: element, attribute: attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return (value as! AXValue)
    }

    private func copyElementArrayAttribute(from element: AXUIElement, attribute: String) -> [AXUIElement]? {
        guard let value = copyAttribute(from: element, attribute: attribute) else {
            return nil
        }

        return value as? [AXUIElement]
    }

    private func copyAttribute(from element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }

        return value
    }

    private func cfRange(from value: AXValue) -> CFRange? {
        guard AXValueGetType(value) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }

        return range
    }
}
