//
//  CancelBlocks.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation


typealias DispatchCancelableBlock = (Bool) -> (Void)

func dispatchMainAsyncAfter(delay: Double, block: DispatchWorkItem?) -> DispatchCancelableBlock? {
    guard let block else {
        return nil
    }
    var cancelableBlock: DispatchCancelableBlock? = nil
    let delayBlock: DispatchCancelableBlock = { (cancel: Bool) -> Void in
        if !cancel {
            DispatchQueue.main.async {
                block.perform()
            }
        }
        cancelableBlock = nil
    }
    cancelableBlock = delayBlock
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
        if let cancelableBlock {
            cancelableBlock(false)
        }
    }
    return cancelableBlock
}

func dispatchCancel(block: DispatchCancelableBlock?) {
    if let block {
        block(true)
    }
}
