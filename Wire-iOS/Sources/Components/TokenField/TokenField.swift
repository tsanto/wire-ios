//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

extension TokenField {
    func filterUnwantedAttachments() {
        var updatedCurrentTokens: Set<AnyHashable> = []
        var updatedCurrentSeparatorTokens: Set<AnyHashable> = []
        
        textView.attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textView.text.count), options: [], using: { textAttachment, range, stop in
            
            if let token = (textAttachment as? TokenTextAttachment)?.token,
                !updatedCurrentTokens.contains(token) {
                updatedCurrentTokens.insert(token)
            }
            
            if let token = (textAttachment as? TokenSeparatorAttachment)?.token,
                !updatedCurrentSeparatorTokens.contains(token) {
                    updatedCurrentSeparatorTokens.insert(token)
            }
        })
        
        ///TODO: check
        updatedCurrentTokens = updatedCurrentTokens.intersection(updatedCurrentSeparatorTokens)
        
        var deletedTokens = Set<AnyHashable>(currentTokens as! [AnyHashable])
        deletedTokens.subtract(updatedCurrentTokens)
        
        if !deletedTokens.isEmpty {
            removeTokens(Array(deletedTokens))
        }
        
        currentTokens = currentTokens.filter({ !Array(deletedTokens).contains($0) })

        delegate?.tokenField(self, changedTokensTo: currentTokens as? [Token])
    }
    
    func add(_ token: Token?) {
        if let token = token {
            if !currentTokens.contains(token) {
                currentTokens.insert(token)
            } else {
                return
            }
        }
        
        updateMaxTitleWidth(for: token)
        
        if !isCollapsed {
            textView.attributedText = string(forTokens: currentTokens)
            // Calling -insertText: forces textView to update its contentSize, while other public methods do not.
            // Broken contentSize leads to broken scrolling to bottom of input field.
            textView.insertText("")
            
                delegate?.tokenField(self, changedFilterTextTo: "")
            
            invalidateIntrinsicContentSize()
            
            // Move the cursor to the end of the input field
            textView.selectedRange = NSRange(location: textView.text.count, length: 0)
            
            // autoscroll to the end of the input field
            setNeedsLayout()
            updateLayout()
            scrollToBottomOfInputField()
        } else {
            textView.attributedText = collapsedString()
            invalidateIntrinsicContentSize()
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if (text == "\n") {
            textView.resignFirstResponder()
            userDidConfirmInput = true
            if delegate.responds(to: #selector(tokenFieldDidConfirmSelection(_:))) {
                delegate.tokenFieldDidConfirmSelection(self)
            }
            
            return false
        }
        
        if range.length == 1 && text.count == 0 {
            // backspace
            var cancelBackspace = false
            textView.attributedText.enumerateAttribute(.attachment, in: range, options: [], using: { tokenAttachment, range, stop in
                if (tokenAttachment is TokenTextAttachment) {
                    if tokenAttachment?.isSelected == nil {
                        textView.selectedRange = range
                        cancelBackspace = true
                    }
                    stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
                }
            })
            if cancelBackspace {
                return false
            }
        }
        
        
        // Inserting text between tokens does not make sense for this control.
        // If there are any tokens after the insertion point, move the cursor to the end instead, but only for insertions
        // If the range length is >0, we are trying to replace something instead, and that’s a bit more complex,
        // so don’t do any magic in that case
        if text.count != 0 {
            (textView.text as NSString).enumerateSubstrings(in: NSRange(location: range.location, length: textView.text.count - range.location), options: .byComposedCharacterSequences, using: { substring, substringRange, enclosingRange, stop in
                
                if (substring?.count ?? 0) != 0 && (substring?[substring?.index(substring?.startIndex, offsetBy: 0)] == .character) {
                    textView.selectedRange = NSRange(location: textView.text.count, length: 0)
                    stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
                }
            })
        }
        
        updateTextAttributes()
        
        return true
    }
}
