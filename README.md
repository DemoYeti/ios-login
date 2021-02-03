# InfomaniakLogin

Library to simplify login process with Infomaniak OAuth 2.0 protocol

## Installation

1. In your Xcode project, go to: File > Swift Packages > Add Package Dependency…
2. Enter the package URL: `git@github.com:Infomaniak/ios-login.git` or `https://github.com/Infomaniak/ios-login.git`

## Usage

### With SFSafariViewController

**If your project has a `SceneDelegate.swift` file:**
1. Add `import InfomaniakLogin` at the top of the file
2. Add this method:
```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
        // Handle URL
        InfomaniakLogin.handleRedirectUri(url: url)
    }
}
```

**If your project doesn't have a `SceneDelegate.swift` file:**
1. Add `import InfomaniakLogin` at the top of your AppDelegate
2. Initialise a `UIWindow` variable inside your AppDelegate:
```swift
var window: UIWindow?
```
3. Add this method inside your AppDelegate:
```swift
func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
    return InfomaniakLogin.handleRedirectUri(url: url)
}
```

**Final part:**

You can now use it where you want by adding the `InfomaniakLoginDelegate` protocol to the class who needs it:

````swift
func didCompleteLoginWith(code: String, verifier: String) {
    InfomaniakLogin.getApiTokenUsing(code: code, codeVerifier: verifier) { (token, error) in 
        // Save the token
    }
}

func didFailLoginWith(error: Error) {
    // Handle the error
}
````

And you can finally use the login fonction, for example with a button, by writing:

````swift
@IBAction func login(_ sender: UIButton) {
    InfomaniakLogin.loginFrom(viewController: self, delegate: self, clientId: clientId, redirectUri: redirectUri)
}
````

With these arguments:
- `clientId`: The client ID of the app
- `redirectUri`: The redirection URL after a successful login (in order to handle the codes)

### With WKWebView

First, add `import InfomaniakLogin` at the top of the file.

You can now use it where you want by adding the `InfomaniakLoginDelegate` protocol to the class who needs it:

````swift
func didCompleteLoginWith(code: String, verifier: String) {
    InfomaniakLogin.getApiTokenUsing(code: code, codeVerifier: verifier) { (token, error) in 
        // Save the token
    }
}

func didFailLoginWith(error: Error) {
    // Handle the error
}
````

And you can finally use the login fonction, for example with a button, by writing:

````swift
@IBAction func login(_ sender: UIButton) {
    InfomaniakLogin.webviewLoginFrom(viewController: self, delegate: self, clientId: clientId, redirectUri: redirectUri)
}
````

With these arguments:
- `clientId`: The client ID of the app
- `redirectUri`: The redirection URL after a successful login (in order to handle the codes)

But if you are using the Web View method, you can also use this method:

````swift
InfomaniakLogin.setupWebviewNavbar(title: nil, color: .red, clearCookie: true)
````

With these arguments:
- `title`: The title that will be shown in the navigation bar
- `color`: The color of the navigation bar
- `clearCookie`:
    - If `true`, the cookie will be deleted when the Web View is closed
    - If `false`, the cookie won't be deleted when the Web View is closed