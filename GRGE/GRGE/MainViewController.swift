import UIKit

class MainViewController: UIViewController {
  static private let instructionsText = "Press and hold in the area above"
  static private let keepHoldingText = "Keep holding…"
  static private let requestMadeText = "Sending request…"
  static private let successText = "Hooray! Door triggered."
  static private let errorText = "Uh oh. Something went wrong."
  
  @IBOutlet var settingsButton: UIButton?
  @IBOutlet var mainButton: UIButton?
  @IBOutlet var mainLabel: UILabel?
  
  private var touchTimer: Timer?
  private var textTimer: Timer?
  private var requestPending = false
  private let isolationQueue = DispatchQueue(label: "com.andybons.GRGE.requestPendingQueue",
                                             attributes: .concurrent)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    mainLabel!.text = MainViewController.instructionsText
    
    let settingsIconImage = UIImage(named: "gears")!.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
    settingsButton!.setImage(settingsIconImage, for: UIControlState.normal)
    settingsButton!.tintColor = UIColor.white
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  @IBAction func onTouchDown(button: UIButton) {
    var reqPending: Bool!
    isolationQueue.sync {
      reqPending = requestPending
    }
    if textTimer != nil || reqPending { return }

    touchTimer = Timer(timeInterval: 3.0,
                       repeats: false,
                       block: {_ in
                         self.clearTouchTimer()
                         self.triggerDoor()
                       })
    RunLoop.current.add(touchTimer!, forMode: RunLoopMode.commonModes)
    setMainLabelText(MainViewController.keepHoldingText)
  }
  
  @IBAction func onTouchUp(button: UIButton) {
    var reqPending: Bool!
    isolationQueue.sync {
      reqPending = requestPending
    }
    if textTimer != nil || reqPending { return }

    clearTouchTimer()
    setMainLabelText(MainViewController.instructionsText)
  }
  
  func setMainLabelText(_ text: String) {
    UIView.transition(with: mainLabel!,
                      duration: 0.25,
                      options: UIViewAnimationOptions.transitionCrossDissolve,
                      animations: { self.mainLabel!.text = text },
                      completion: nil)
  }
  
  func setMainLabelText(_ text: String, forDuration: TimeInterval) {
    clearTextTimer()
    setMainLabelText(text)
    textTimer = Timer(timeInterval: 3.0,
                      repeats: false,
                      block: {_ in
                        self.clearTextTimer()
                        self.setMainLabelText(MainViewController.instructionsText)
                      }
    )
    RunLoop.main.add(textTimer!, forMode: RunLoopMode.commonModes)
  }
  
  func clearTextTimer() {
    if textTimer != nil {
      textTimer!.invalidate()
      textTimer = nil
    }
  }
  
  func clearTouchTimer() {
    if touchTimer != nil {
      touchTimer!.invalidate()
      touchTimer = nil
    }
  }
  
  func triggerDoor() {
    let defaults = UserDefaults.standard
    let baseURL = defaults.string(forKey: UserSettingsKey.baseURL)
    let sharedSecret = defaults.string(forKey: UserSettingsKey.sharedSecret)
    if baseURL == nil || sharedSecret == nil {
      print("Must set base URL and shared secret")
      return
    }
    let timeSinceEpoch = String(Int(NSDate().timeIntervalSince1970))
    let key = hmacsha1(str: timeSinceEpoch, key: sharedSecret!)
    let url = URL(string: "\(baseURL!)?t=\(timeSinceEpoch)&key=\(key)")
    isolationQueue.async(flags: .barrier) {
      self.requestPending = true
    }
    setMainLabelText(MainViewController.requestMadeText)
    print("Making request to \(url!)")
    let task = URLSession.shared.dataTask(with: url!, completionHandler: {
      data, response, error in
      
      self.isolationQueue.async(flags: .barrier) {
        self.requestPending = false
      }

      if let errorStr = error?.localizedDescription {
        print("error:", errorStr)
        DispatchQueue.main.async {
          self.setMainLabelText(MainViewController.errorText, forDuration: 5.0)
        }
      } else if let httpResponse = response as? HTTPURLResponse {
        print("Status: \(httpResponse.statusCode)")
        if  httpResponse.statusCode == 200 {
          DispatchQueue.main.async {
            self.setMainLabelText(MainViewController.successText, forDuration: 5.0)
          }
        } else {
          DispatchQueue.main.async {
            self.setMainLabelText(MainViewController.errorText, forDuration: 5.0)
          }
        }
        if data != nil {
          let body = String(data:data!, encoding:String.Encoding.utf8)
          print("Response body: \(body!)")
        }
      }
    })
    task.resume()
  }
  
  func hmacsha1(str: String, key: String) -> String {
    let cData = str.cString(using: String.Encoding.utf8)!
    let cKey = key.cString(using: String.Encoding.utf8)!
    var result = [CUnsignedChar](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), cKey, Int(strlen(cKey)), cData, Int(strlen(cData)), &result)
    let hexBytes = result.map { String(format: "%02hhx", $0) }
    return hexBytes.joined()
  }
}
