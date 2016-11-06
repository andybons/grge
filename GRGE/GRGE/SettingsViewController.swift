import UIKit

struct UserSettingsKey {
  static let baseURL = "baseURL"
  static let sharedSecret = "sharedSecret"
}

class SettingsViewController: UIViewController {
  @IBOutlet var baseURLTextField: UITextField?
  @IBOutlet var sharedSecretTextField: UITextField?

  override func viewDidLoad() {
    super.viewDidLoad()

    let fields: Array<UITextField> = [self.baseURLTextField!, self.sharedSecretTextField!];
    for textField in fields {
      textField.layer.shadowOffset = CGSize(width: 0, height: 1.0)
      textField.layer.shadowOpacity = 0.15;
      textField.layer.shadowColor = UIColor.white.cgColor
      textField.layer.shadowRadius = 1.0;
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let defaults = UserDefaults.standard
    self.baseURLTextField!.text = defaults.string(forKey: UserSettingsKey.baseURL)
    self.sharedSecretTextField!.text = defaults.string(forKey: UserSettingsKey.sharedSecret)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let defaults = UserDefaults.standard
    defaults.set(self.baseURLTextField!.text, forKey: UserSettingsKey.baseURL)
    defaults.set(self.sharedSecretTextField!.text, forKey: UserSettingsKey.sharedSecret)
  }
}
