// REQUIRES: OS=ios
// REQUIRES: objc_interop
// RUN: %target-swift-frontend -emit-ir -g %s -o - | FileCheck %s

import UIKit
@available(iOS, introduced=8.0)
class ActionViewController
{
  var imageView: UIImageView!
  func viewDidLoad(inputItems: [AnyObject]) {
    for item: AnyObject in inputItems {
      let inputItem = item as! NSExtensionItem
      for provider: AnyObject in inputItem.attachments! {
        let itemProvider = provider as! NSItemProvider
// CHECK: load {{.*}}selector
// CHECK:; <label>{{.*}}  ; preds = %{{[0-9]+}}
// CHECK: @swift_allocObject({{.*}}, !dbg ![[DBG:[0-9]+]]
// Test that the location is reset at the entry of a new basic block.        
// CHECK: ![[DBG]] = {{.*}}line: 0
        if itemProvider.hasItemConforming(toTypeIdentifier: "") {
          weak var weakImageView = self.imageView
          itemProvider.loadItem(forTypeIdentifier: "", options: nil,
               completionHandler: { (image, error) in
              if let imageView = weakImageView {
              }
            })
        }
      }
    }
  }
}
