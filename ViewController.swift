//
//  ViewController.swift
//  PhoneNumberCapture
//
//  Created by David G. Young on 4/30/18.
//  Copyright © 2018 David G. Young. All rights reserved.
//

import UIKit
import MessageUI

class ViewController: UIViewController, MFMessageComposeViewControllerDelegate {
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    var composeVC = MFMessageComposeViewController()
    let AWSQueryEndpointURL = /* TODO: Paste your AWS Query Endpoint URL here */
    let AwsPhoneNumber = /* TODO: Paste your AWS Phone number here */

    var smsVerificationStartTime: Date?
    var deviceUuid: String {
        get {
            if let val = UserDefaults.standard.string(forKey: "deviceUuid") {
                return val
            }
            let val = UUID().uuidString
            self.deviceUuid = val
            return val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "deviceUuid")
        }
    }
    var phoneNumber: String? {
        get {
            return UserDefaults.standard.string(forKey: "phoneNumber")
        }
        set {
            return UserDefaults.standard.set(newValue, forKey: "phoneNumber")
        }
    }
    let dateFormatter = DateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        updateView()
    }

    func updateView() {
        if phoneNumber != nil {
            label.text = "Phone Number: \(phoneNumber!)"
            button.setTitle("Reset Phone Number", for: .normal)
            spinner.isHidden = true
        }
        else if smsVerificationStartTime == nil {
            label.text = "Phone number not verified"
            button.setTitle("Verify Phone Number", for: .normal)
            spinner.isHidden = true
        }
        else {
            label.text = "Verifying phone number..."
            button.setTitle("Cancel Verification", for: .normal)
            spinner.isHidden = false
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buttonTapped(_ sender: Any) {
        if smsVerificationStartTime != nil {
            smsVerificationStartTime = nil
            updateView()
        }
        else if (phoneNumber == nil) {
            capturePhoneNumber()
        }
        else {
            clearPhoneNumber()
            updateView()
        }
    }
    
    func clearPhoneNumber() {
        UserDefaults.standard.set(nil, forKey: "phoneNumber")
    }
    
    func capturePhoneNumber() {
        if !MFMessageComposeViewController.canSendText() {
            let alert = UIAlertController(title: "Cannot send SMS", message: "SMS messaging is unavailable on this device.  You may not use a Simulator, an iPod Touch, or a Phone without cell service.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler:  {(alert: UIAlertAction!) in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        else {
            let alert = UIAlertController(title: "Prepare to send message", message: "A message dialog will be presented to register your device id and phone number with our servers.  Please ensure you have cell connectivty, and tap OK.  When the messaging window appears, please do not alter the message or the destination phone number otherwise registration will fail. ", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler:  {(alert: UIAlertAction!) in
                self.composeVC.messageComposeDelegate = self
                
                // Configure the fields of the interface.
                self.composeVC.recipients = [self.AWSPhoneNumber]
                self.composeVC.body = "device_uuid:\(self.deviceUuid)"
                self.composeVC.disableUserAttachments()
                
                // Present the view controller modally.
                self.present(self.composeVC, animated: true, completion: nil)
                // Set up a new one to use next time, as these are slow to
                // get ready
                self.composeVC = MFMessageComposeViewController()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (alert: UIAlertAction!) in
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
        
        smsVerificationStartTime = Date()
        updateView()
        verifySmsAfterDelay()
    }
    
    func verifySmsAfterDelay() {
        guard let smsVerificationStartTime = smsVerificationStartTime else {
            return
        }

        // If 30 secs has passed since we started verification, give up.
        if Date().timeIntervalSince(smsVerificationStartTime) > 60.0 {
            self.smsVerificationStartTime = nil
            DispatchQueue.main.async {
                self.updateView()
                let alert = UIAlertController(title: "Timeout Verifying Phone Number", message: "Please check your network connectivity and try again", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler:  {(alert: UIAlertAction!) in
                }))
                self.present(alert, animated: true, completion: nil)
            }
            return
        }
        
        // execute the following code in one second
        NSLog("Waiting one second before checking SMS verification")
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
            NSLog("Checking SMS verification")
            DeviceApi(server: self.AWSQueryEndpointURL).query(deviceUuid: self.deviceUuid, completionHandler: { (resultDict, error) in
                guard resultDict != nil, error == nil, let deviceDict = resultDict!["device"] as? [String:String] else {
                    let errorMessage = resultDict?["errorMessage"] as? String ?? error
                    NSLog("error calling device service: \(errorMessage ?? "no error")")
                    self.verifySmsAfterDelay()
                    return
                }
                NSLog("Result: \(resultDict!)" )
                self.phoneNumber = deviceDict["phone_number"]
                let validationTime = self.dateFormatter.date(from: deviceDict["sns_publish_time"] ?? "")
                guard let validationTimeNotNil = validationTime, validationTimeNotNil > smsVerificationStartTime else {
                    if validationTime == nil {
                        NSLog("SNS publish time could not be parsed: \(deviceDict["sns_publish_time"] ?? "nil")")
                    }
                    else {
                        NSLog("phone number was verified only prior to this verification operation (\(validationTime!) <= \(smsVerificationStartTime))")
                    }
                    self.verifySmsAfterDelay()
                    return
                }
                self.phoneNumber = deviceDict["origination_number"]
                if (self.phoneNumber == nil) {
                    self.verifySmsAfterDelay()
                }
                else {
                    // We have a new phone number and its verification time was after we started this sms verification
                    // this means we are done!
                    self.smsVerificationStartTime = nil
                    DispatchQueue.main.async {
                        self.updateView()
                    }
                }
            })
        }
        
    }

}

