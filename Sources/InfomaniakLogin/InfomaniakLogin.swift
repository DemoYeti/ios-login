/*
Copyright 2020 Infomaniak Network SA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import UIKit
import CommonCrypto
import SafariServices
import WebKit

@objc public protocol InfomaniakLoginDelegate {
    func didCompleteLoginWith(code: String, verifier: String)
    func didFailLoginWith(error: String)
}

public struct Constants {
    public static let LOGIN_URL = "https://login.infomaniak.com/"
    public static let RESPONSE_TYPE = "code"
    public static let ACCESS_TYPE = "offline"
    public static let HASH_MODE = "SHA-256"
    public static let HASH_MODE_SHORT = "S256"
}

@objc public class InfomaniakLogin: NSObject {

    private static let LOGIN_API_URL = "https://login.infomaniak.com/"
    private static let GET_TOKEN_API_URL = LOGIN_API_URL + "token"

    private static let instance = InfomaniakLogin()
    private var delegate: InfomaniakLoginDelegate?

    private var clientId: String!
    private var loginUrl: String!
    private var redirectUri: String!

    private var codeChallenge: String!
    private var codeChallengeMethod: String!
    private var codeVerifier: String!

    private var safariViewController: SFSafariViewController?

    private var clearCookie: Bool? = false
    private var webViewController: WebViewController?
    private var webviewNavbarButtonColor: UIColor? = nil
    private var webviewNavbarColor: UIColor? = nil
    private var webviewNavbarTitle: String? = nil
    private var webviewNavbarTitleColor: UIColor? = nil
    private var webviewTimeOutMessage: String? = nil

    private override init() {
    }

    @objc public static func initWith(clientId: String,
        loginUrl: String = Constants.LOGIN_URL,
        redirectUri: String = "\(Bundle.main.bundleIdentifier ?? "")://oauth2redirect") {
        instance.loginUrl = loginUrl
        instance.clientId = clientId
        instance.redirectUri = redirectUri
    }

    @objc public static func handleRedirectUri(url: URL) -> Bool {
        return checkResponse(url: url,
            onSuccess: { (code) in
                instance.safariViewController?.dismiss(animated: true) {
                    instance.delegate?.didCompleteLoginWith(code: code, verifier: instance.codeVerifier)
                }
            },

            onFailure: { (error) in
                instance.safariViewController?.dismiss(animated: true) {
                    instance.delegate?.didFailLoginWith(error: error)
                }
            }
        )
    }

    @objc static func webviewHandleRedirectUri(url: URL) -> Bool {
        return checkResponse(url: url,
            onSuccess: { (code) in
                instance.webViewController?.dismiss(animated: true) {
                    instance.delegate?.didCompleteLoginWith(code: code, verifier: instance.codeVerifier)
                }
            },

            onFailure: { (error) in
                instance.webViewController?.dismiss(animated: true) {
                    instance.delegate?.didFailLoginWith(error: error)
                }
            }
        )
    }

    @objc static func checkResponse(url: URL, onSuccess: (String) -> Void, onFailure: (String) -> Void) -> Bool {
        if let code = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value {
            onSuccess(code)
            return true
        } else {
            onFailure("Accès refusé")
            return false
        }
    }

    @objc public static func loginFrom(viewController: UIViewController, delegate: InfomaniakLoginDelegate? = nil, defaultEmail: String? = nil) {
        let instance = InfomaniakLogin.instance
        instance.delegate = delegate
        instance.generatePkceCodes()
        instance.generateUrl()

        guard let url = getFormattedLoginUrl(with: defaultEmail) else {
            return
        }

        instance.safariViewController = SFSafariViewController(url: url)
        viewController.present(instance.safariViewController!, animated: true)
    }

    @objc public static func webviewLoginFrom(viewController: UIViewController, delegate: InfomaniakLoginDelegate? = nil, defaultEmail: String? = nil) {
        let instance = InfomaniakLogin.instance
        instance.delegate = delegate
        instance.generatePkceCodes()
        instance.generateUrl()

        guard let url = getFormattedLoginUrl(with: defaultEmail) else {
            return
        }

        let urlRequest = URLRequest(url: url)
        instance.webViewController = WebViewController()

        let navigationController = UINavigationController(rootViewController: instance.webViewController!)

        viewController.present(navigationController, animated: true)
        instance.webViewController?.urlRequest = urlRequest
        instance.webViewController?.redirectUri = instance.redirectUri
        instance.webViewController?.clearCookie = instance.clearCookie
        instance.webViewController?.navBarTitle = instance.webviewNavbarTitle
        instance.webViewController?.navBarTitleColor = instance.webviewNavbarTitleColor
        instance.webViewController?.navBarColor = instance.webviewNavbarColor
        instance.webViewController?.navBarButtonColor = instance.webviewNavbarButtonColor
        instance.webViewController?.timeOutMessage = instance.webviewTimeOutMessage

    }

    @objc public static func setupWebviewNavbar(title: String?, titleColor: UIColor?, color: UIColor?, buttonColor: UIColor?, clearCookie: Bool = false, timeOutMessage: String?) {
        instance.webviewNavbarTitle = title
        instance.webviewNavbarTitleColor = titleColor
        instance.webviewNavbarColor = color
        instance.webviewNavbarButtonColor = buttonColor
        instance.clearCookie = clearCookie
        instance.webviewTimeOutMessage = timeOutMessage
    }

    /**
     * Get an api token async (callback on background thread)
     */
    @objc public static func getApiTokenUsing(code: String, codeVerifier: String, completion: @escaping (ApiToken?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: GET_TOKEN_API_URL)!)

        let parameterDictionary: [String: Any] = [
            "grant_type": "authorization_code",
            "client_id": instance.clientId!,
            "code": code,
            "code_verifier": codeVerifier,
            "redirect_uri": instance.redirectUri ?? ""]
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameterDictionary.percentEncoded()

        getApiToken(request: request, completion: completion)
    }

    /**
    * Get an api token async from an application password (callback on background thread)
    */
    @objc public static func getApiToken(username: String, applicationPassword: String, completion: @escaping (ApiToken?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: GET_TOKEN_API_URL)!)

        let parameterDictionary: [String: Any] = [
            "grant_type": "password",
            "access_type": "offline",
            "client_id": instance.clientId!,
            "username": username,
            "password": applicationPassword]
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameterDictionary.percentEncoded()

        getApiToken(request: request, completion: completion)
    }

    /**
     * Refresh api token async (callback on background thread)
     */
    @objc public static func refreshToken(token: ApiToken, completion: @escaping (ApiToken?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: GET_TOKEN_API_URL)!)

        let parameterDictionary: [String: Any] = [
            "grant_type": "refresh_token",
            "client_id": instance.clientId!,
            "refresh_token": token.refreshToken]
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameterDictionary.percentEncoded()

        getApiToken(request: request, completion: completion)
    }

    private static func getApiToken(request: URLRequest, completion: @escaping (ApiToken?, Error?) -> Void) {
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, sessionError) in
            guard let response = response as? HTTPURLResponse,
                let data = data, data.count > 0 else {
                completion(nil, sessionError)
                return
            }

            do {
                if response.isSuccessful() {
                    let apiToken = try JSONDecoder().decode(ApiToken.self, from: data)
                    completion(apiToken, nil)
                } else {
                    let apiError = try JSONDecoder().decode(ApiError.self, from: data)
                    completion(nil, NSError(domain: apiError.error, code: response.statusCode, userInfo: ["Error": apiError]))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }

    private func generatePkceCodes() {
        codeChallengeMethod = Constants.HASH_MODE_SHORT
        codeVerifier = generateCodeVerifier()
        codeChallenge = generateCodeChallenge(codeVerifier: codeVerifier)
    }

    /**
    * Generate the complete login URL based on parameters and base
    */
    private func generateUrl() {
        loginUrl = loginUrl + "authorize/" +
            "?response_type=\(Constants.RESPONSE_TYPE)" +
            "&access_type=\(Constants.ACCESS_TYPE)" +
            "&client_id=\(clientId!)" +
            "&redirect_uri=\(redirectUri!)" +
            "&code_challenge_method=\(codeChallengeMethod!)" +
            "&code_challenge=\(codeChallenge!)"
    }

    /**
    * Generate a verifier code for PKCE challenge (rfc7636 4.1.)
    * https://auth0.com/docs/api-auth/tutorials/authorization-code-grant-pkce
    */
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /**
    * Generate a challenge code for PKCE challenge (rfc7636 4.2.)
    * https://auth0.com/docs/api-auth/tutorials/authorization-code-grant-pkce
    */
    private func generateCodeChallenge(codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else {
            return ""
        }
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func getFormattedLoginUrl(with email: String? = nil) -> URL? {
        var urlComponents = URLComponents(string: instance.loginUrl)
        if let email = email {
            urlComponents?.path = "/login"
            urlComponents?.queryItems = [URLQueryItem(name: "login", value: email)]
        }

        return urlComponents?.url
    }

}

extension HTTPURLResponse {
    func isSuccessful() -> Bool {
        return statusCode >= 200 && statusCode <= 299
    }
}

extension Dictionary {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
