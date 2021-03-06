//
//  OSDViewController.swift
//  Mobile Flight
//
//  Created by Raphael Jean-Leconte on 14/05/17.
//  Copyright © 2017 Raphael Jean-Leconte. All rights reserved.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import UIKit
import SVProgressHUD
import Firebase

class OSDViewController: UIViewController, UIScrollViewDelegate {
    @IBOutlet weak var osdView: OSDPreview!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var osdViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var osdViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var osdViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var osdViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var plusButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if OSD.theOSD.elements.isEmpty {
            msp.sendMessage(.MSP_OSD_CONFIG, data: nil, retry: 2) { success in
                dispatch_async(dispatch_get_main_queue()) {
                    if success {
                        if !OSD.theOSD.supported {
                            self.saveButton.enabled = false
                            self.plusButton.enabled = false
                            SVProgressHUD.showInfoWithStatus("This flight controller doesn't support OSD")
                        } else {
                            self.osdView.createElementViews()
                            self.saveButton.enabled = true
                            self.plusButton.enabled = true
                        }
                    } else {
                        self.saveButton.enabled = false
                        self.plusButton.enabled = false
                        SVProgressHUD.showErrorWithStatus("Communication error")
                    }
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateMinZoomScaleForSize(scrollView.bounds.size)
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return osdView
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        updateConstraintsForSize(scrollView.bounds.size)
    }
    
    private func updateMinZoomScaleForSize(size: CGSize) {
        let widthScale = size.width / osdView.bounds.width
        let heightScale = size.height / osdView.bounds.height
        let minScale = min(widthScale, heightScale)
        
        scrollView.minimumZoomScale = minScale
        // Set the current zoom scale so that the full width or height of the scroll view is used
        scrollView.zoomScale = max(widthScale, heightScale)
        // Center the OSD in the scroll view
        scrollView.contentOffset.x = scrollView.contentSize.width / 2 - size.width / 2
        scrollView.contentOffset.y = scrollView.contentSize.height / 2 - size.height / 2
    }
    
    private func updateConstraintsForSize(size: CGSize) {
        
        let yOffset = max(0, (size.height - osdView.frame.height) / 2)
        osdViewTopConstraint.constant = yOffset
        osdViewBottomConstraint.constant = yOffset
        
        let xOffset = max(0, (size.width - osdView.frame.width) / 2)
        osdViewLeadingConstraint.constant = xOffset
        osdViewTrailingConstraint.constant = xOffset
        
        view.layoutIfNeeded()
    }
    
    func refreshUI() {
        osdView.updateVisibleViews()
    }
    
    @IBAction func saveAction(sender: AnyObject) {
        Analytics.logEvent("osd_saved", parameters: nil)
        SVProgressHUD.showWithStatus("Saving OSD configuration", maskType: .Black)
        appDelegate.stopTimer()
        msp.sendOsdConfig(OSD.theOSD) { success in
            dispatch_async(dispatch_get_main_queue()) {
                if success {
                    SVProgressHUD.dismiss()
                } else {
                    Analytics.logEvent("osd_saved_failed", parameters: nil)
                    SVProgressHUD.showErrorWithStatus("Save failed")
                }
                self.appDelegate.startTimer()
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vc = segue.destinationViewController as? OSDSettingsViewController {
            vc.osdViewController = self
        }
    }
}
