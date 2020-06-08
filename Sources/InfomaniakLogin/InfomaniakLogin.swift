#if canImport(UIKit)
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

        private var loginUrl: String!
        private var clientId: String!
        private var redirectUri: String!

        private var codeChallengeMethod: String!
        private var codeChallenge: String!

        private var safariViewController: SFSafariViewController?
        private var webViewController: WebViewController?
        private var navigationController: UINavigationController?

        private static let instance = InfomaniakLogin()

        private var delegate: InfomaniakLoginDelegate?
        private var codeVerifier: String!
        
        private var webviewNavbarTitle: String? = nil
        private var webviewNavbarColor: UIColor? = nil

        private override init() {
        }


        @objc public static func handleRedirectUri(url: URL) -> Bool {
            return checkResponse(url: url,
                onSuccess: { (code) in
                    instance.safariViewController?.dismiss(animated: true) {
                        instance.delegate?.didCompleteLoginWith(code: code, verifier: instance.codeVerifier)
                    } },

                onFailure: { (error) in
                    instance.safariViewController?.dismiss(animated: true) {
                        instance.delegate?.didFailLoginWith(error: error)
                    }
                }
            )
        }
        
        @objc public static func webviewHandleRedirectUri(url: URL) -> Bool {
            return checkResponse(url: url,
                onSuccess: { (code) in
                    instance.webViewController?.dismiss(animated: true) {
                        instance.delegate?.didCompleteLoginWith(code: code, verifier: instance.codeVerifier)
                    } },

                onFailure: { (error) in
                    instance.webViewController?.dismiss(animated: true) {
                        instance.delegate?.didFailLoginWith(error: error)
                    }
                }
            )
        }

        @objc static func checkResponse(url: URL,
            onSuccess: (String) -> Void,
            onFailure: (String) -> Void
        ) -> Bool {
            if let code = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value {
                onSuccess(code)
                return true
            } else {
                onFailure("Accès refusé")
                return false
            }
        }


        @objc public static func loginFrom(viewController: UIViewController, delegate: InfomaniakLoginDelegate? = nil, loginUrl: String? = Constants.LOGIN_URL, clientId: String, redirectUri: String) {
            let instance = InfomaniakLogin.instance
            instance.delegate = delegate
            instance.loginUrl = loginUrl!
            instance.clientId = clientId
            instance.redirectUri = redirectUri
            instance.generatePkceCodes()
            instance.generateUrl()

            guard let url = URL(string: instance.loginUrl) else {
                return
            }
            
            instance.safariViewController = SFSafariViewController(url: url)
            viewController.present(instance.safariViewController!, animated: true)
        }
        
        
        @objc public static func webviewLoginFrom(viewController: UIViewController, delegate: InfomaniakLoginDelegate? = nil, loginUrl: String = Constants.LOGIN_URL, clientId: String, redirectUri: String, clearCookie: Bool) {
            let instance = InfomaniakLogin.instance
            instance.delegate = delegate
            instance.loginUrl = loginUrl
            instance.clientId = clientId
            instance.redirectUri = redirectUri
            instance.generatePkceCodes()
            instance.generateUrl()
            
            guard let url = URL(string: instance.loginUrl) else {
                return
            }
            let urlRequest = URLRequest(url: url)
            instance.webViewController = WebViewController()

            let navigationController = UINavigationController(rootViewController: instance.webViewController!)
            
            viewController.present(navigationController, animated: true)
            instance.webViewController?.urlRequest = urlRequest
            instance.webViewController?.clearCookie = clearCookie
            instance.webViewController?.navBarTitle = instance.webviewNavbarTitle
            instance.webViewController?.navBarColor = instance.webviewNavbarColor
            
        }
        
        
        public static func setupWebviewNavbar(title: String?, color: UIColor?) {
            instance.webviewNavbarTitle = title
            instance.webviewNavbarColor = color
        }
        

        /**
     * Get an api token async (callbakc on background thread)
     */
        @objc public static func getApiTokenUsing(code: String, codeVerifier: String, completion: @escaping (ApiToken?, Error?) -> Void) {
            var request = URLRequest(url: URL(string: "https://login.infomaniak.com/token")!)

            let parameterDictionary: [String: Any] = [
                "grant_type": "authorization_code",
                "client_id": instance.clientId ?? "",
                "code": code,
                "code_verifier": codeVerifier,
                "redirect_uri": instance.redirectUri ?? ""]
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = parameterDictionary.percentEncoded()

            let session = URLSession.shared
            session.dataTask(with: request) { (data, response, sessionError) in
                if let response = response as? HTTPURLResponse {
                    if response.isSucessful() && data != nil && data!.count > 0 {
                        do {
                            let apiToken = try JSONDecoder().decode(ApiToken.self, from: data!)
                            completion(apiToken, nil)
                        } catch {
                            completion(nil, error)
                        }
                    } else {
                        completion(nil, sessionError)
                    }
                } else {
                    completion(nil, sessionError)
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
    }

    extension HTTPURLResponse {
        func isSucessful() -> Bool {
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

#endif
