//
//  SnapKit
//
//  Copyright (c) 2011-Present SnapKit Team - https://github.com/SnapKit
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif


public extension ConstraintView {
    @available(*, deprecated, renamed: "snp.left")
    var snp_left: ConstraintItem { self.snp.left }

    @available(*, deprecated, renamed: "snp.top")
    var snp_top: ConstraintItem { self.snp.top }

    @available(*, deprecated, renamed: "snp.right")
    var snp_right: ConstraintItem { self.snp.right }

    @available(*, deprecated, renamed: "snp.bottom")
    var snp_bottom: ConstraintItem { self.snp.bottom }

    @available(*, deprecated, renamed: "snp.leading")
    var snp_leading: ConstraintItem { self.snp.leading }

    @available(*, deprecated, renamed: "snp.trailing")
    var snp_trailing: ConstraintItem { self.snp.trailing }

    @available(*, deprecated, renamed: "snp.width")
    var snp_width: ConstraintItem { self.snp.width }

    @available(*, deprecated, renamed: "snp.height")
    var snp_height: ConstraintItem { self.snp.height }

    @available(*, deprecated, renamed: "snp.centerX")
    var snp_centerX: ConstraintItem { self.snp.centerX }

    @available(*, deprecated, renamed: "snp.centerY")
    var snp_centerY: ConstraintItem { self.snp.centerY }

    @available(*, deprecated, renamed: "snp.baseline")
    var snp_baseline: ConstraintItem { self.snp.baseline }

    @available(*, deprecated, renamed: "snp.lastBaseline")
    @available(iOS 8.0, OSX 10.11, *)
    var snp_lastBaseline: ConstraintItem { self.snp.lastBaseline }

    @available(iOS, deprecated, renamed: "snp.firstBaseline")
    @available(iOS 8.0, OSX 10.11, *)
    var snp_firstBaseline: ConstraintItem { self.snp.firstBaseline }

    @available(iOS, deprecated, renamed: "snp.leftMargin")
    @available(iOS 8.0, *)
    var snp_leftMargin: ConstraintItem { self.snp.leftMargin }

    @available(iOS, deprecated, renamed: "snp.topMargin")
    @available(iOS 8.0, *)
    var snp_topMargin: ConstraintItem { self.snp.topMargin }

    @available(iOS, deprecated, renamed: "snp.rightMargin")
    @available(iOS 8.0, *)
    var snp_rightMargin: ConstraintItem { self.snp.rightMargin }

    @available(iOS, deprecated, renamed: "snp.bottomMargin")
    @available(iOS 8.0, *)
    var snp_bottomMargin: ConstraintItem { self.snp.bottomMargin }

    @available(iOS, deprecated, renamed: "snp.leadingMargin")
    @available(iOS 8.0, *)
    var snp_leadingMargin: ConstraintItem { self.snp.leadingMargin }

    @available(iOS, deprecated, renamed: "snp.trailingMargin")
    @available(iOS 8.0, *)
    var snp_trailingMargin: ConstraintItem { self.snp.trailingMargin }

    @available(iOS, deprecated, renamed: "snp.centerXWithinMargins")
    @available(iOS 8.0, *)
    var snp_centerXWithinMargins: ConstraintItem { self.snp.centerXWithinMargins }

    @available(iOS, deprecated, renamed: "snp.centerYWithinMargins")
    @available(iOS 8.0, *)
    var snp_centerYWithinMargins: ConstraintItem { self.snp.centerYWithinMargins }

    @available(*, deprecated, renamed: "snp.edges")
    var snp_edges: ConstraintItem { self.snp.edges }

    @available(*, deprecated, renamed: "snp.size")
    var snp_size: ConstraintItem { self.snp.size }

    @available(*, deprecated, renamed: "snp.center")
    var snp_center: ConstraintItem { self.snp.center }

    @available(iOS, deprecated, renamed: "snp.margins")
    @available(iOS 8.0, *)
    var snp_margins: ConstraintItem { self.snp.margins }

    @available(iOS, deprecated, renamed: "snp.centerWithinMargins")
    @available(iOS 8.0, *)
    var snp_centerWithinMargins: ConstraintItem { self.snp.centerWithinMargins }

    @available(*, deprecated, renamed: "snp.prepareConstraints(_:)")
    func snp_prepareConstraints(_ closure: (_ make: ConstraintMaker) -> Void) -> [Constraint] {
        self.snp.prepareConstraints(closure)
    }

    @available(*, deprecated, renamed: "snp.makeConstraints(_:)")
    func snp_makeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        self.snp.makeConstraints(closure)
    }

    @available(*, deprecated, renamed: "snp.remakeConstraints(_:)")
    func snp_remakeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        self.snp.remakeConstraints(closure)
    }

    @available(*, deprecated, renamed: "snp.updateConstraints(_:)")
    func snp_updateConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        self.snp.updateConstraints(closure)
    }

    @available(*, deprecated, renamed: "snp.removeConstraints()")
    func snp_removeConstraints() {
        self.snp.removeConstraints()
    }

    var snp: ConstraintViewDSL {
        ConstraintViewDSL(view: self)
    }
}
